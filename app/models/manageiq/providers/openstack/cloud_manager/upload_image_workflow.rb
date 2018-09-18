class ManageIQ::Providers::Openstack::CloudManager::UploadImageWorkflow < Job
  def self.create_job(ext_management_system_id, image_id, url, timeout: 1.hour, poll_interval: 1.minute)
    options = {
      :ext_management_system_id => ext_management_system_id,
      :url                      => url,
      :image_id                 => image_id,
      :timeout                  => timeout,
      :poll_interval            => poll_interval,
    }

    super(name, options)
  end

  def upload_image
    ext_management_system_id, image_id, url = options.values_at(:ext_management_system, :image_id, :url)

    EmsCloud.find(ext_management_system_id).with_provider_connection(:service => 'Image') do |service|
      options[:uploading] = true
      started_on = Time.now.utc
      update_attributes!(:started_on => started_on)
      miq_task.update_attributes!(:started_on => started_on)
      queue_signal(:poll_runner)

      image = service.images.find_by_id(image_id)
      service.handle_upload(image, url)
      options[:uploading] = false
    end
    rescue => err
      _log.error("image=[#{name}], error=[#{err}]")
      queue_signal(:abort, "Failed to upload image", "error")
  end

  def poll_runner
    uploading = context[:uploading?]
    if uploading
      if started_on + options[:timeout] < Time.now.utc
        queue_signal(:abort, "Playbook has been running longer than timeout", "error")
      else
        queue_signal(:poll_runner, :deliver_on => deliver_on)
      end
    else
      queue_signal(:post_upload_image)
    end
  end

  alias initializing dispatch_start
  alias start        upload_image
  alias finish       process_finished
  alias abort_job    process_abort
  alias cancel       process_cancel
  alias error        process_error

  protected

  def queue_signal(*args, deliver_on: nil)
    role     = options[:role] || "ems_operations"
    priority = options[:priority] || MiqQueue::NORMAL_PRIORITY

    MiqQueue.put(
      :class_name  => self.class.name,
      :method_name => "signal",
      :instance_id => id,
      :priority    => priority,
      :role        => role,
      :zone        => zone,
      :task_id     => guid,
      :args        => args,
      :deliver_on  => deliver_on,
      :server_guid => MiqServer.my_server.guid,
    )
  end

  def deliver_on
    Time.now.utc + options[:poll_interval]
  end

  def load_transitions
    self.state ||= 'initialize'

    {
      :initializing => {'initialize'       => 'waiting_to_start'},
      :start        => {'waiting_to_start' => 'upload_image'},
      :upload_image => {'upload_image'     => 'running'},
      :poll_runner  => {'running'          => 'running'},
      :finish       => {'*'                => 'finished'},
      :abort_job    => {'*'                => 'aborting'},
      :cancel       => {'*'                => 'canceling'},
      :error        => {'*'                => '*'}
    }
  end
end
