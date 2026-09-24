# frozen_string_literal: true

require "minitest/autorun"
require "time"
require_relative "lib/asc_review_submission"

class FakeASCMutationClient
  attr_reader :calls

  def initialize
    @responses = Hash.new { |hash, key| hash[key] = [] }
    @calls = []
  end

  def enqueue(method, path, response)
    @responses[[method, path]] << response
  end

  def get(path, query = nil)
    take(:get, path, query)
  end

  def paginate(path, query = nil, max_pages: 20)
    _ = max_pages
    take(:paginate, path, query)
  end

  def post(path, payload)
    take(:post, path, payload)
  end

  def patch(path, payload)
    take(:patch, path, payload)
  end

  private

  def take(method, path, argument)
    @calls << [method, path, argument]
    response = @responses.fetch([method, path]).shift
    raise "missing fake response for #{method} #{path}" if response.nil?
    raise response if response.is_a?(Exception)

    response
  end
end

class ASCReviewSubmissionTest < Minitest::Test
  Submission = MajiaCI::ASCReviewSubmission
  APP_ID = "1234567890"
  VERSION_ID = "version-100"

  def test_creates_review_submission_item_and_submits_existing_version
    client = prepared_client
    client.enqueue(:paginate, "/v1/apps/#{APP_ID}/reviewSubmissions", [])
    client.enqueue(:post, "/v1/reviewSubmissions", { "data" => review_submission("submission-1", "READY_FOR_REVIEW") })
    client.enqueue(:post, "/v1/reviewSubmissionItems", { "data" => { "id" => "item-1" } })
    client.enqueue(:patch, "/v1/reviewSubmissions/submission-1", {})
    client.enqueue(
      :get,
      "/v1/reviewSubmissions/submission-1",
      { "data" => review_submission("submission-1", "WAITING_FOR_REVIEW") }
    )

    summary = Submission.submit(
      client: client,
      bundle_id: "com.example.app",
      marketing_version: "1.0.0",
      submitted_at: Time.utc(2026, 9, 24, 5, 0, 0)
    )

    assert_equal true, summary["review_submitted"]
    assert_equal false, summary["no_op"]
    assert_equal "WAITING_FOR_REVIEW", summary.dig("review_submission", "state")
    assert_equal "42", summary.dig("build", "version")
    mutation_methods = client.calls.filter_map do |method, _path, _argument|
      method if %i[post patch].include?(method)
    end
    assert_equal [:post, :post, :patch], mutation_methods
    patch = client.calls.find { |method, path, _argument| method == :patch && path.end_with?("submission-1") }
    assert_equal true, patch[2].dig("data", "attributes", "submitted")
  end

  def test_reuses_ready_review_submission_that_already_contains_version
    client = prepared_client
    client.enqueue(
      :paginate,
      "/v1/apps/#{APP_ID}/reviewSubmissions",
      [review_submission("submission-1", "READY_FOR_REVIEW")]
    )
    client.enqueue(
      :paginate,
      "/v1/reviewSubmissions/submission-1/items",
      [review_item("item-1", VERSION_ID)]
    )
    client.enqueue(:patch, "/v1/reviewSubmissions/submission-1", {})
    client.enqueue(
      :get,
      "/v1/reviewSubmissions/submission-1",
      { "data" => review_submission("submission-1", "IN_REVIEW") }
    )

    summary = Submission.submit(
      client: client,
      bundle_id: "com.example.app",
      marketing_version: "1.0.0"
    )

    assert_equal "IN_REVIEW", summary.dig("review_submission", "state")
    refute client.calls.any? { |method, _path, _argument| method == :post }
  end

  def test_already_submitted_version_is_an_idempotent_no_op
    client = prepared_client(version_state: "WAITING_FOR_REVIEW")
    client.enqueue(
      :paginate,
      "/v1/apps/#{APP_ID}/reviewSubmissions",
      [review_submission("submission-1", "WAITING_FOR_REVIEW")]
    )
    client.enqueue(
      :paginate,
      "/v1/reviewSubmissions/submission-1/items",
      [review_item("item-1", VERSION_ID, "WAITING_FOR_REVIEW")]
    )

    summary = Submission.submit(
      client: client,
      bundle_id: "com.example.app",
      marketing_version: "1.0.0"
    )

    assert_equal true, summary["review_submitted"]
    assert_equal true, summary["no_op"]
    assert_equal "already_submitted", summary["no_op_reason"]
    refute client.calls.any? { |method, _path, _argument| %i[post patch].include?(method) }
  end

  def test_submission_requires_an_attached_valid_build
    client = prepared_client(build_state: "FAILED")

    error = assert_raises(MajiaCI::ASCSubmissionError) do
      Submission.submit(
        client: client,
        bundle_id: "com.example.app",
        marketing_version: "1.0.0"
      )
    end

    assert_includes error.message, "not processing-complete and VALID"
    refute client.calls.any? { |method, _path, _argument| %i[post patch].include?(method) }
  end

  def test_active_review_submission_for_another_version_blocks_submission
    client = prepared_client
    client.enqueue(
      :paginate,
      "/v1/apps/#{APP_ID}/reviewSubmissions",
      [review_submission("active-submission", "IN_REVIEW")]
    )

    error = assert_raises(MajiaCI::ASCSubmissionError) do
      Submission.submit(
        client: client,
        bundle_id: "com.example.app",
        marketing_version: "1.0.0"
      )
    end

    assert_includes error.message, "another iOS review submission is active"
    refute client.calls.any? { |method, _path, _argument| %i[post patch].include?(method) }
  end

  def test_standalone_workflow_selects_app_and_version_without_signing_or_upload
    text = File.read(File.expand_path("../workflows/asc-submit-review.yml", __dir__), encoding: "UTF-8")

    %w[
      tripcost-production hearthio-production sdpacket-production photo-production
      plotproof_lab-production
    ].each do |environment|
      assert_includes text, "- #{environment}"
    end
    assert_includes text, "marketing_version:"
    assert_includes text, "environment: ${{ inputs.app_environment }}"
    assert_includes text, "if: ${{ github.ref == 'refs/heads/main' }}"
    assert_includes text, "group: majia-asc-${{ inputs.app_environment }}-${{ github.repository }}"
    assert_includes text, "ruby .github/scripts/submit-asc-review.rb"
    assert_includes text, "ASC_API_KEY_P8: ${{ secrets.ASC_API_KEY_P8 }}"
    refute_includes text, "IOS_DISTRIBUTION_P12_BASE64"
    refute_includes text, "IOS_APPSTORE_PROFILE_BASE64"
    refute_includes text, "upload_to_asc"
  end

  def test_release_workflows_use_the_same_submission_script_after_store_preparation
    workflows = {
      "photo-ios-ci.yml" => "photo-production",
      "tripcost-ios-release.yml" => "tripcost-production",
      "donesome-ios-release.yml" => "hearthio-production",
      "sdpacket-ios-release.yml" => "sdpacket-production",
      "plotproof-lab-ios-release.yml" => "plotproof_lab-production"
    }
    workflows.each do |name, environment|
      text = File.read(File.expand_path("../workflows/#{name}", __dir__), encoding: "UTF-8")
      assert_includes text, "group: majia-asc-#{environment}-${{ github.repository }}"
      assert_includes text, 'submit_to_review: "false"'
      assert_includes text, "if: ${{ inputs.submit }}"
      assert_includes text, "ruby .github/scripts/submit-asc-review.rb"
      assert_includes text, "--marketing-version \"$MARKETING_VERSION\""
      assert_includes text, "REVIEW_SUBMITTED: ${{ steps.submit_review.outputs.review_submitted }}"
    end
  end

  private

  def prepared_client(version_state: "PREPARE_FOR_SUBMISSION", build_state: "VALID")
    client = FakeASCMutationClient.new
    client.enqueue(:paginate, "/v1/apps", [app])
    client.enqueue(
      :paginate,
      "/v1/apps/#{APP_ID}/appStoreVersions",
      [version("1.0.0", version_state)]
    )
    client.enqueue(
      :get,
      "/v1/appStoreVersions/#{VERSION_ID}/relationships/build",
      { "data" => { "type" => "builds", "id" => "build-42" } }
    )
    client.enqueue(
      :get,
      "/v1/builds/build-42",
      {
        "data" => {
          "type" => "builds",
          "id" => "build-42",
          "attributes" => {
            "version" => "42",
            "processingState" => build_state,
            "uploadedDate" => "2026-09-24T04:00:00Z",
            "expired" => false
          }
        }
      }
    )
    client
  end

  def app
    {
      "type" => "apps",
      "id" => APP_ID,
      "attributes" => { "name" => "Example", "bundleId" => "com.example.app" }
    }
  end

  def version(number, state)
    {
      "type" => "appStoreVersions",
      "id" => VERSION_ID,
      "attributes" => {
        "platform" => "IOS",
        "versionString" => number,
        "appVersionState" => state,
        "createdDate" => "2026-09-24T03:00:00Z"
      }
    }
  end

  def review_submission(id, state)
    {
      "type" => "reviewSubmissions",
      "id" => id,
      "attributes" => { "platform" => "IOS", "state" => state }
    }
  end

  def review_item(id, version_id, state = "READY_FOR_REVIEW")
    {
      "type" => "reviewSubmissionItems",
      "id" => id,
      "attributes" => { "state" => state },
      "relationships" => {
        "appStoreVersion" => { "data" => { "type" => "appStoreVersions", "id" => version_id } }
      }
    }
  end
end
