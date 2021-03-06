require 'spec_helper'

module SecureHeaders
  describe Configuration do
    before(:each) do
      reset_config
      Configuration.default
    end

    it "has a default config" do
      expect(Configuration.get(Configuration::DEFAULT_CONFIG)).to_not be_nil
    end

    it "has an 'noop' config" do
      expect(Configuration.get(Configuration::NOOP_CONFIGURATION)).to_not be_nil
    end

    it "precomputes headers upon creation" do
      default_config = Configuration.get(Configuration::DEFAULT_CONFIG)
      header_hash = default_config.cached_headers.each_with_object({}) do |(key, value), hash|
        header_name, header_value = if key == :csp
          value["Chrome"]
        else
          value
        end

        hash[header_name] = header_value
      end
      expect_default_values(header_hash)
    end

    it "copies all config values except for the cached headers when dup" do
      Configuration.override(:test_override, Configuration::NOOP_CONFIGURATION) do
        # do nothing, just copy it
      end

      config = Configuration.get(:test_override)
      noop = Configuration.get(Configuration::NOOP_CONFIGURATION)
      [:hsts, :x_frame_options, :x_content_type_options, :x_xss_protection,
        :x_download_options, :x_permitted_cross_domain_policies, :hpkp, :csp].each do |key|

        expect(config.send(key)).to eq(noop.send(key)), "Value not copied: #{key}."
      end
    end

    it "stores an override of the global config" do
      Configuration.override(:test_override) do |config|
        config.x_frame_options = "DENY"
      end

      expect(Configuration.get(:test_override)).to_not be_nil
    end

    it "deep dup's config values when overriding so the original cannot be modified" do
      Configuration.override(:override) do |config|
        config.csp[:default_src] << "'self'"
      end

      default = Configuration.get
      override = Configuration.get(:override)

      expect(override.csp).not_to eq(default.csp)
    end

    it "allows you to override an override" do
      Configuration.override(:override) do |config|
        config.csp = { default_src: %w('self')}
      end

      Configuration.override(:second_override, :override) do |config|
        config.csp = config.csp.merge(script_src: %w(example.org))
      end

      original_override = Configuration.get(:override)
      expect(original_override.csp).to eq(default_src: %w('self'))
      override_config = Configuration.get(:second_override)
      expect(override_config.csp).to eq(default_src: %w('self'), script_src: %w(example.org))
    end
  end
end
