# frozen_string_literal: true

require "digest"

module MajiaCI
  # Extends the pinned uploader: retain matching uploads across interrupted runs.
  module ASCMediaResume
    def replace!(manifest, localizations)
      @staged_media_collections = []
      @stage_media_collections = true
      begin
        summary = super
      ensure
        @stage_media_collections = false
      end
      @staged_media_collections.each { |collection| finish_media_collection(**collection) }
      summary
    ensure
      @staged_media_collections = nil
    end

    private

    def replace_collection(localization_id, contract, display_type, files)
      set = find_or_create_set(localization_id, contract, display_type)
      existing = existing_assets(set.fetch("id"), contract)
      used = []
      desired = files.map do |path|
        checksum = Digest::MD5.file(path).hexdigest
        matches = existing.select do |asset|
          attrs = asset.fetch("attributes", {})
          state = media_delivery_state(asset, contract)
          !used.include?(asset.fetch("id")) && attrs["fileName"] == File.basename(path) &&
            attrs["fileSize"] == File.size(path) && attrs["sourceFileChecksum"].to_s.downcase == checksum &&
            %w[COMPLETE UPLOAD_COMPLETE].include?(state)
        end
        asset = matches.find { |candidate| media_delivery_state(candidate, contract) == "COMPLETE" } || matches.first
        used << asset.fetch("id") if asset
        asset
      end
      obsolete = existing.reject { |asset| used.include?(asset.fetch("id")) }
      maximum = contract.fetch(:asset_type) == "appScreenshots" ? 10 : 3
      # Fail without deleting existing assets when there is no staging capacity.
      excess = [existing.length + desired.count(nil) - maximum, 0].max
      if excess.positive?
        raise IOSBuild::ASC::ReleaseError, "ASC collection capacity prevents safe staged replacement for #{display_type}"
      end
      begin
        @defer_media_processing = true
        desired = desired.each_with_index.map do |asset, index|
          asset || upload_asset(set.fetch("id"), contract, files[index])
        end
      ensure
        @defer_media_processing = false
      end

      collection = { set: set, contract: contract, desired: desired, obsolete: obsolete, display_type: display_type, reused: used.length }
      if @stage_media_collections
        @staged_media_collections << collection
      else
        finish_media_collection(**collection)
      end
    end

    def finish_media_collection(set:, contract:, desired:, obsolete:, display_type:, reused:)
      desired.each do |asset|
        next if media_delivery_state(asset, contract) == "COMPLETE"

        wait_for_processing(asset.fetch("id"), contract)
      end
      # Old images remain recoverable until every desired replacement is ready.
      obsolete.each do |asset|
        @client.delete("#{contract.fetch(:asset_path)}/#{asset.fetch('id')}")
      end
      relation = "#{contract.fetch(:set_path)}/#{set.fetch('id')}/relationships/#{contract.fetch(:asset_relationship)}"
      expected = desired.map { |asset| { "type" => contract.fetch(:asset_type), "id" => asset.fetch("id") } }
      @client.patch(relation, { "data" => expected })
      observed = Array(@client.get(relation)["data"])
      unless observed.map { |asset| asset["id"] } == expected.map { |asset| asset["id"] }
        raise IOSBuild::ASC::ReleaseError, "failed to verify ordered resumed #{contract.fetch(:asset_relationship)} replacement"
      end
      warn "ASC media verified: #{display_type}, #{desired.length} assets (#{reused} reused)"
    end

    def wait_for_processing(asset_id, contract)
      if @defer_media_processing
        # upload_asset has committed the complete bytes and checksum. Defer its
        # processing wait until the rest of this collection has been sent too.
        return @client.get("#{contract.fetch(:asset_path)}/#{asset_id}").fetch("data")
      end

      super
    end

    def media_delivery_state(asset, contract)
      asset.dig("attributes", contract.fetch(:state_attribute), "state") ||
        asset.dig("attributes", "assetDeliveryState", "state")
    end
  end
end
