module ManageIQ::Providers::Openstack::HelperMethods
  extend ActiveSupport::Concern

  def parse_error_message_from_fog_response(exception)
    self.class.parse_error_message_from_fog_response(exception)
  end

  def parse_error_message_from_neutron_response(exception)
    self.class.parse_error_message_from_neutron_response(exception)
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
  end
end
