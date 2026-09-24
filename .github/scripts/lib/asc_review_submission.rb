# frozen_string_literal: true

require "time"
require_relative "asc_review_status"

module MajiaCI
  class ASCSubmissionError < StandardError; end

  module ASCReviewSubmission
    module_function

    EDITABLE_VERSION_STATES = %w[
      PREPARE_FOR_SUBMISSION READY_FOR_REVIEW DEVELOPER_REJECTED METADATA_REJECTED
      REJECTED INVALID_BINARY WAITING_FOR_EXPORT_COMPLIANCE
    ].freeze
    SUBMITTED_VERSION_STATES = %w[
      WAITING_FOR_REVIEW IN_REVIEW ACCEPTED PENDING_APPLE_RELEASE PENDING_CONTRACT
      PENDING_DEVELOPER_RELEASE PROCESSING_FOR_APP_STORE PROCESSING_FOR_DISTRIBUTION
    ].freeze
    RELEASED_VERSION_STATES = %w[
      READY_FOR_SALE READY_FOR_DISTRIBUTION PREORDER_READY_FOR_SALE
      DEVELOPER_REMOVED_FROM_SALE REMOVED_FROM_SALE REPLACED_WITH_NEW_VERSION
    ].freeze
    BLOCKING_SUBMISSION_STATES = %w[
      WAITING_FOR_REVIEW IN_REVIEW UNRESOLVED_ISSUES CANCELING COMPLETING
    ].freeze
    SUBMITTED_REVIEW_STATES = %w[WAITING_FOR_REVIEW IN_REVIEW COMPLETING COMPLETE].freeze

    def submit(client:, bundle_id:, marketing_version:, submitted_at: Time.now.utc)
      app = ASCReviewStatus.resolve_app(client, bundle_id)
      version = ASCReviewStatus.resolve_version(client, app.fetch("id"), marketing_version)
      build = ASCReviewStatus.resolve_build(client, version.fetch("id"))
      observed_version = version.dig("attributes", "versionString")
      unless observed_version == marketing_version
        raise ASCSubmissionError,
              "ASC returned App Store version #{observed_version || 'UNKNOWN'} instead of #{marketing_version}"
      end
      version_state = version.dig("attributes", "appVersionState")
      summary = base_summary(
        app: app,
        version: version,
        build: build,
        marketing_version: marketing_version,
        submitted_at: submitted_at
      )

      if RELEASED_VERSION_STATES.include?(version_state)
        return summary.merge("no_op" => true, "no_op_reason" => "already_released")
      end
      if SUBMITTED_VERSION_STATES.include?(version_state)
        submission = ASCReviewStatus.resolve_review_submission(client, app.fetch("id"), version.fetch("id"))
        return summary.merge(
          "review_submission" => summarize_submission(submission),
          "review_submitted" => true,
          "no_op" => true,
          "no_op_reason" => "already_submitted"
        )
      end
      unless EDITABLE_VERSION_STATES.include?(version_state)
        raise ASCSubmissionError,
              "App Store version #{marketing_version} cannot be submitted in state #{version_state || 'UNKNOWN'}"
      end
      raise ASCSubmissionError, "App Store version #{marketing_version} has no attached build" unless build

      build_state = build.dig("attributes", "processingState")
      unless build_state == "VALID"
        raise ASCSubmissionError, "attached build is not processing-complete and VALID; observed #{build_state || 'UNKNOWN'}"
      end
      if build.dig("attributes", "expired")
        raise ASCSubmissionError, "attached build is expired"
      end

      submission = ensure_review_submission(
        client: client,
        app_id: app.fetch("id"),
        version_id: version.fetch("id")
      )
      summary.merge(
        "review_submission" => summarize_submission(submission),
        "review_submitted" => true
      )
    end

    def markdown(summary)
      app = summary.fetch("app", {})
      version = summary.fetch("version", {})
      build = summary.fetch("build", {}) || {}
      submission = summary.fetch("review_submission", {}) || {}
      lines = [
        "## ASC review submission",
        "",
        "- App: #{display(app['name'])} (`#{display(app['bundle_id'])}`)",
        "- Marketing version: #{display(version['version_string'])}",
        "- Build number: #{display(build['version'])}",
        "- App Store version state before submission: `#{display(version['app_version_state'])}`",
        "- Review submitted or already submitted: `#{summary.fetch('review_submitted', false)}`",
        "- Review submission state: `#{display(submission['state'])}`",
        "- No-op: `#{summary.fetch('no_op', false)}`",
        "- No-op reason: `#{display(summary['no_op_reason'])}`",
        "- Checked at: #{display(summary['submitted_at'])}",
        "",
        "> #{summary.fetch('evidence_boundary')}",
        ""
      ]
      lines.join("\n")
    end

    def ensure_review_submission(client:, app_id:, version_id:)
      submissions = review_submissions(client, app_id)
      target = submissions.find do |submission|
        submission.dig("attributes", "state") == "READY_FOR_REVIEW" &&
          submission_contains_version?(client, submission.fetch("id"), version_id)
      end
      return submit_review(client, target) if target

      blocker = submissions.find do |submission|
        BLOCKING_SUBMISSION_STATES.include?(submission.dig("attributes", "state"))
      end
      if blocker
        raise ASCSubmissionError,
              "another iOS review submission is active in state #{blocker.dig('attributes', 'state')}"
      end

      submission = submissions.find { |candidate| candidate.dig("attributes", "state") == "READY_FOR_REVIEW" }
      submission ||= create_review_submission(client, app_id)
      create_review_item(client, submission.fetch("id"), version_id)
      submit_review(client, submission)
    end

    def review_submissions(client, app_id)
      client.paginate(
        "/v1/apps/#{app_id}/reviewSubmissions",
        { "filter[platform]" => "IOS", "limit" => "200" }
      )
    end
    private_class_method :review_submissions

    def submission_contains_version?(client, submission_id, version_id)
      client.paginate(
        "/v1/reviewSubmissions/#{submission_id}/items",
        { "limit" => "200" }
      ).any? do |item|
        item.dig("relationships", "appStoreVersion", "data", "id") == version_id
      end
    end
    private_class_method :submission_contains_version?

    def create_review_submission(client, app_id)
      client.post(
        "/v1/reviewSubmissions",
        {
          "data" => {
            "type" => "reviewSubmissions",
            "attributes" => { "platform" => "IOS" },
            "relationships" => {
              "app" => { "data" => { "type" => "apps", "id" => app_id } }
            }
          }
        }
      ).fetch("data")
    end
    private_class_method :create_review_submission

    def create_review_item(client, submission_id, version_id)
      client.post(
        "/v1/reviewSubmissionItems",
        {
          "data" => {
            "type" => "reviewSubmissionItems",
            "relationships" => {
              "reviewSubmission" => {
                "data" => { "type" => "reviewSubmissions", "id" => submission_id }
              },
              "appStoreVersion" => {
                "data" => { "type" => "appStoreVersions", "id" => version_id }
              }
            }
          }
        }
      )
    end
    private_class_method :create_review_item

    def submit_review(client, submission)
      submission_id = submission.fetch("id")
      client.patch(
        "/v1/reviewSubmissions/#{submission_id}",
        {
          "data" => {
            "type" => "reviewSubmissions",
            "id" => submission_id,
            "attributes" => { "submitted" => true }
          }
        }
      )
      observed = client.get("/v1/reviewSubmissions/#{submission_id}").fetch("data")
      state = observed.dig("attributes", "state")
      unless SUBMITTED_REVIEW_STATES.include?(state)
        raise ASCSubmissionError,
              "review submission did not enter a submitted state; observed #{state || 'UNKNOWN'}"
      end
      observed
    end
    private_class_method :submit_review

    def base_summary(app:, version:, build:, marketing_version:, submitted_at:)
      {
        "schema_version" => 1,
        "submitted_at" => submitted_at.utc.iso8601,
        "requested_marketing_version" => marketing_version,
        "app" => {
          "id" => app.fetch("id"),
          "name" => app.dig("attributes", "name"),
          "bundle_id" => app.dig("attributes", "bundleId")
        },
        "version" => {
          "id" => version.fetch("id"),
          "version_string" => version.dig("attributes", "versionString"),
          "app_version_state" => version.dig("attributes", "appVersionState")
        },
        "build" => ASCReviewStatus.summarize_build(build),
        "review_submission" => nil,
        "review_submitted" => false,
        "no_op" => false,
        "no_op_reason" => nil,
        "evidence_boundary" =>
          "ASC API submission result. It does not build, upload, release, or prove approval or distribution."
      }
    end
    private_class_method :base_summary

    def summarize_submission(submission)
      return nil unless submission

      {
        "id" => submission.fetch("id"),
        "state" => submission.dig("attributes", "state") || submission["state"]
      }
    end
    private_class_method :summarize_submission

    def display(value)
      value.nil? || value.to_s.empty? ? "not available" : value
    end
    private_class_method :display
  end
end
