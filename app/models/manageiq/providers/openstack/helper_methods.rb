module ManageIQ::Providers::Openstack::HelperMethods
  extend ActiveSupport::Concern

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
    def parse_error_message_from_fog_response(exception)
      exception_string = exception.to_s
      matched_message = exception_string.match(/message\\\": \\\"(.*)\\\", /)
      matched_message ? matched_message[1] : exception_string
    end

    def parse_error_message_from_neutron_response(exception)
      JSON.parse(exception.response.body)["NeutronError"]["message"]
    end

    def with_notification(type, options: {})
      # extract success and error options from options
      # :success and :error keys respectively
      # with all other keys common for both cases
      success_options = options.delete(:success) || {}
      error_options = options.delete(:error) || {}
      success_options.merge!(options)
      error_options.merge!(options)
      begin
        yield
      rescue => ex
        # Fog specific
        error_message = parse_error_message_from_fog_response(ex.to_s)
        Notification.create(:type => "#{type}_error".to_sym, :options => error_options.merge(:error_message => error_message))
        raise
      else
        Notification.create(:type => "#{type}_success".to_sym, :options => success_options)
      end
    end
  end
end
