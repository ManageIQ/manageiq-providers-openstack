module ManageIQ::Providers::Openstack::HelperMethods
  extend ActiveSupport::Concern

  # Return the openstack proxy, if any, as a string. Otherwise return nil.
  def openstack_proxy
    ManageIQ::Providers::Openstack::CloudManager.http_proxy_uri&.to_s
  end

  def parse_error_message_from_fog_response(exception)
    self.class.parse_error_message_from_fog_response(exception)
  end

  def parse_error_message_from_neutron_response(exception)
    self.class.parse_error_message_from_neutron_response(exception)
  end

  def with_notification(type, options: {}, &block)
    self.class.with_notification(type, :options => options, &block)
  end

  module ClassMethods
    def openstack_proxy
      ManageIQ::Providers::Openstack::CloudManager.http_proxy_uri&.to_s
    end

    def parse_error_message_from_fog_response(exception)
      exception_string = exception.respond_to?(:response) ? exception.response&.body : exception.to_s
      matched_message = exception_string.match(/"message": "(.*)"/)
      matched_message ? matched_message[1] : exception_string
    end

    def parse_error_message_from_neutron_response(exception)
      # not a neutron exception
      return exception.to_s unless exception.respond_to?(:response)

      if exception.kind_of?(::Excon::Error::BadRequest) || exception.kind_of?(::Excon::Error::Conflict)
        response_body = JSON.parse(exception.response.body)
        response_body["NeutronError"]["message"] if response_body.key?("NeutronError")
      elsif exception.kind_of?(::Excon::Error::HTTPStatus)
        # undercloud neutron-server service is stopped
        parse_error_message_excon_http_status(exception)
      else
        parse_error_message_from_fog_response(exception)
      end
    end

    def parse_error_message_excon_http_status(exception)
      Nokogiri::HTML.parse(exception.response.body).text.gsub('\n', ' ')
    end

    def with_notification(type, options: {})
      # extract success and error options from options
      # :success and :error keys respectively
      # with all other keys common for both cases
      success_options = options.delete(:success) || {}
      error_options = options.delete(:error) || {}
      success_options.merge!(options)
      error_options.merge!(options)

      # copy subject, initiator and cause from options
      named_options_keys = [:subject, :initiator, :cause]
      named_options = {}
      named_options_keys.map do |key|
        named_options[key] = options.fetch(key, nil)
      end

      begin
        yield
      rescue => ex
        # Fog specific
        error_message = parse_error_message_from_fog_response(ex)
        Notification.create(:type => "#{type}_error".to_sym, :options => error_options.merge(:error_message => error_message), **named_options)
        raise
      else
        Notification.create(:type => "#{type}_success".to_sym, :options => success_options, **named_options)
      end
    end
  end
end
