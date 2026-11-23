# frozen_string_literal: true

require_relative "asc_review_status"

module MajiaCI
  class ASCCancellationError < StandardError
    attr_reader :evidence

    def initialize(message, evidence: nil)
      super(message)
      @evidence = evidence
    end
  end

  module ASCReviewCancellation
    module_function

    APP_ID = "6822704143"
    BUNDLE_ID = "com.tripdelta.lite.app"
    MARKETING_VERSION = "1.0.8"
    VERSION_ID = "7bbae275-c2da-4caf-942a-f8f35277f8cc"
    SUBMISSION_ID = "32bf7b05-f4db-4c68-8e7e-2990c1e36f61"
    TRIPDELTA_108 = { version: MARKETING_VERSION, version_id: VERSION_ID, submission_id: SUBMISSION_ID }.freeze
    TRIPDELTA_111 = {
      version: "1.0.11", version_id: "aa007b7c-9070-4ab0-8ff9-d4e009e2fffe",
      submission_id: "102ab665-d7ba-4e88-b9fe-4335d10d4edb",
      build_id: "ee3d1478-e00d-43a4-9495-8a280c5851ed", build_number: "2"
    }.freeze
    ITEM_RELATIONSHIPS = %w[
      appStoreVersion appAssetLibraryImage appAssetLibraryVideo appCustomProductPageVersion
      appEvent appStoreVersionExperiment appStoreVersionExperimentV2 backgroundAssetVersion
      gameCenterAchievementVersion gameCenterActivityVersion gameCenterChallengeVersion
      gameCenterLeaderboardSetVersion gameCenterLeaderboardVersion inAppPurchaseVersion
      retentionMessageVersion subscriptionGroupVersion subscriptionVersion
    ].freeze
    ACTIVE_STATES = %w[WAITING_FOR_REVIEW IN_REVIEW].freeze

    def cancel(client:, target: TRIPDELTA_108, poll_seconds: 5, max_polls: 24, sleeper: ->(seconds) { sleep(seconds) })
      evidence = {
        "schema_version" => 1, "requested_app_id" => APP_ID,
        "requested_bundle_id" => BUNDLE_ID, "requested_marketing_version" => target.fetch(:version),
        "requested_version_id" => target.fetch(:version_id), "requested_submission_id" => target.fetch(:submission_id),
        "cancel_requested" => false, "completed" => false, "no_op" => false,
        "evidence_boundary" => "Cancels only the identified review submission. Does not delete builds, submit, or release."
      }
      unless target.equal?(TRIPDELTA_108) || target.equal?(TRIPDELTA_111)
        raise ASCCancellationError, "unsupported cancellation target"
      end
      submission_id = target.fetch(:submission_id)
      unless max_polls.is_a?(Integer) && max_polls.positive? && poll_seconds.is_a?(Numeric) && poll_seconds >= 0
        raise ASCCancellationError, "invalid cancellation polling limits"
      end
      app = ASCReviewStatus.resolve_app(client, BUNDLE_ID)
      unless app["id"] == APP_ID && app.dig("attributes", "bundleId") == BUNDLE_ID
        raise ASCCancellationError, "ASC app identity mismatch"
      end
      version = ASCReviewStatus.resolve_version(client, APP_ID, target.fetch(:version))
      verify_version!(version, target)
      submissions = client.paginate("/v1/apps/#{APP_ID}/reviewSubmissions", {
        "filter[platform]" => "IOS", "limit" => "200"
      })
      matches = submissions.select { |submission| submission["id"] == submission_id }
      unless matches.length == 1 && matches.first["type"] == "reviewSubmissions" &&
             matches.first.dig("attributes", "platform") == "IOS"
        raise ASCCancellationError, "authorized review submission was not uniquely identified within the target app"
      end
      before = snapshot(client, target, version: version)
      evidence["before"] = before
      evidence["after"] = before
      if target.key?(:build_id) && before["build"] != { "id" => target[:build_id], "version" => target[:build_number] }
        raise ASCCancellationError, "linked build does not match the authorized build"
      end
      if completed?(before)
        evidence["completed"] = true
        evidence["no_op"] = true
        return evidence
      end
      state = before.fetch("submission_state")
      unless ACTIVE_STATES.include?(state) || state == "CANCELING"
        raise ASCCancellationError, "review submission cannot be canceled in state #{state}"
      end
      unless %w[WAITING_FOR_REVIEW IN_REVIEW].include?(before.fetch("version_state")) || state == "CANCELING"
        raise ASCCancellationError, "App Store version is no longer under review"
      end
      evidence["verified_item"] = verify_items!(client, target)
      if state != "CANCELING"
        evidence["cancel_requested"] = true
        begin
          client.patch("/v1/reviewSubmissions/#{submission_id}", {
            "data" => { "type" => "reviewSubmissions", "id" => submission_id,
                        "attributes" => { "canceled" => true } }
          })
        rescue StandardError => error
          begin
            evidence["after"] = snapshot(client, target)
          rescue StandardError
            evidence["readback_failed"] = true
          end
          raise ASCCancellationError.new("cancellation PATCH failed; inspect readback before retry: #{error.message}", evidence: evidence)
        end
      else
        evidence["cancel_requested"] = true
        evidence["no_op"] = true
      end
      max_polls.times do |index|
        sleeper.call(poll_seconds) if index.positive?
        observed = snapshot(client, target)
        evidence["after"] = observed
        unless observed["build"] == before["build"]
          raise ASCCancellationError, "attached build changed during cancellation"
        end
        if completed?(observed)
          evidence["completed"] = true
          return evidence
        end
        unless %w[WAITING_FOR_REVIEW IN_REVIEW CANCELING COMPLETE].include?(observed["submission_state"])
          raise ASCCancellationError, "unexpected cancellation readback state #{observed['submission_state']}"
        end
      end
      raise ASCCancellationError, "cancellation not confirmed within polling limit"
    rescue ASCCancellationError => error
      raise error if error.evidence

      raise ASCCancellationError.new(error.message, evidence: evidence)
    rescue StandardError => error
      raise ASCCancellationError.new("cancellation could not be verified: #{error.message}", evidence: evidence)
    end

    def verify_version!(version, target)
      unless version["type"] == "appStoreVersions" && version["id"] == target.fetch(:version_id) &&
             version.dig("attributes", "versionString") == target.fetch(:version) &&
             version.dig("attributes", "platform") == "IOS"
        raise ASCCancellationError, "ASC version identity mismatch"
      end
    end
    private_class_method :verify_version!

    def snapshot(client, target, version: nil)
      version_id = target.fetch(:version_id)
      submission_id = target.fetch(:submission_id)
      version ||= client.get("/v1/appStoreVersions/#{version_id}").fetch("data")
      verify_version!(version, target)
      submission = client.get("/v1/reviewSubmissions/#{submission_id}").fetch("data")
      unless submission["type"] == "reviewSubmissions" && submission["id"] == submission_id &&
             submission.dig("attributes", "platform") == "IOS"
        raise ASCCancellationError, "ASC submission identity mismatch"
      end
      build = ASCReviewStatus.resolve_build(client, version_id)
      {
        "checked_at" => Time.now.utc.iso8601, "version_id" => version_id,
        "version_state" => version.dig("attributes", "appVersionState"),
        "submission_id" => submission_id, "submission_state" => submission.dig("attributes", "state"),
        "build" => build && { "id" => build["id"], "version" => build.dig("attributes", "version") }
      }
    end
    private_class_method :snapshot

    def completed?(observed)
      observed["submission_state"] == "COMPLETE" && observed["version_state"] == "DEVELOPER_REJECTED"
    end
    private_class_method :completed?

    def verify_items!(client, cancellation_target)
      items = client.paginate("/v1/reviewSubmissions/#{cancellation_target.fetch(:submission_id)}/items", {
        "include" => "appStoreVersion",
        "limit" => "200"
      })
      raise ASCCancellationError, "review submission must contain exactly one item" unless items.length == 1

      item = items.first
      raise ASCCancellationError, "unexpected review submission item type" unless item["type"] == "reviewSubmissionItems"

      relationships = item.fetch("relationships")
      target = relationship_data(client, item, "appStoreVersion", relationships.fetch("appStoreVersion"))
      unless target == { "type" => "appStoreVersions", "id" => cancellation_target.fetch(:version_id) }
        raise ASCCancellationError, "review submission item does not match the exact version"
      end
      relationships.each do |name, relationship|
        next if name == "appStoreVersion"
        unless ITEM_RELATIONSHIPS.include?(name)
          raise ASCCancellationError, "review submission has unknown material relationships"
        end
        unless relationship_data(client, item, name, relationship).nil?
          raise ASCCancellationError, "review submission contains another material or unknown linkage: #{name}"
        end
      end
      { "id" => item.fetch("id"), "app_store_version" => target }
    end
    private_class_method :verify_items!

    def relationship_data(client, item, name, relationship)
      return relationship["data"] if relationship.key?("data")

      link = relationship.dig("links", "self")
      expected_path = "/v1/reviewSubmissionItems/#{item.fetch('id')}/relationships/#{name}"
      unless link == expected_path || link == "#{ASCReviewStatus::API_ORIGIN}#{expected_path}"
        raise ASCCancellationError, "review submission has unverified relationship linkage: #{name}"
      end
      response = client.get(expected_path)
      raise ASCCancellationError, "missing relationship data: #{name}" unless response.key?("data")

      response["data"]
    end
    private_class_method :relationship_data
  end
end
