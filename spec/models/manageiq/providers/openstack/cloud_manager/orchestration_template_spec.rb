describe ManageIQ::Providers::Openstack::CloudManager::OrchestrationTemplate do
  describe ".eligible_manager_types" do
    it "lists the classes of eligible managers" do
      described_class.eligible_manager_types.each do |klass|
        expect(klass <= ManageIQ::Providers::Openstack::CloudManager).to be_truthy
      end
    end
  end

  let(:yaml_template) { FactoryBot.create(:orchestration_template_openstack_in_yaml) }
  let(:json_template) { FactoryBot.create(:orchestration_template_openstack_in_json) }

  shared_examples_for "a template with content" do
    it "parses parameters from a template" do
      groups = template.parameter_groups
      expect(groups.size).to eq(2)

      assert_general_group(groups[0])
      assert_db_group(groups[1])
    end
  end

  describe "JSON template" do
    it_should_behave_like "a template with content" do
      let(:template) { json_template }
    end
  end

  describe "YAML template" do
    it_should_behave_like "a template with content" do
      let(:template) { yaml_template }
    end
  end

  def assert_general_group(group)
    expect(group.label).to eq("General parameters")
    expect(group.description).to eq("General parameters")

    assert_custom_constraint(group.parameters[0])
    assert_allowed_values(group.parameters[1])
    assert_list_string_type(group.parameters[2])
  end

  def assert_db_group(group)
    expect(group.label).to be_nil
    expect(group.description).to be_nil

    assert_hidden_length_patterns(group.parameters[0])
    assert_min_max_value(group.parameters[1])
    assert_json_type(group.parameters[2])
    assert_boolean_type(group.parameters[3])
    assert_list_type(group.parameters[4])
    assert_aws_type(group.parameters[5])
  end

  def assert_custom_constraint(parameter)
    expect(parameter).to have_attributes(
      :name          => "flavor",
      :label         => "Flavor",
      :description   => "Flavor for the instances to be created",
      :data_type     => "string",
      :default_value => "m1.small",
      :hidden        => false,
      :required      => true
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(1)
    expect(constraints[0]).to be_a ::OrchestrationTemplate::OrchestrationParameterCustom
    expect(constraints[0]).to be_kind_of ::OrchestrationTemplate::OrchestrationParameterConstraint
    expect(constraints[0]).to have_attributes(
      :description       => "Must be a flavor known to Nova",
      :custom_constraint => "nova.flavor"
    )
  end

  def assert_list_string_type(parameter)
    expect(parameter).to have_attributes(
      :name          => "cartridges",
      :label         => "Cartridges",
      :description   => "Cartridges to install. \"all\" for all cartridges; \"standard\" for all cartridges except for JBossEWS or JBossEAP\n",
      :data_type     => match(/comma_delimited_list|CommaDelimitedList/),
      :default_value => %w(cron diy haproxy mysql nodejs perl php postgresql python ruby).join("\n"),
      :hidden        => false,
      :required      => true,
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(1)
    expect(constraints[0]).to be_a ::OrchestrationTemplate::OrchestrationParameterMultiline
    expect(constraints[0]).to be_kind_of ::OrchestrationTemplate::OrchestrationParameterConstraint
  end

  def assert_allowed_values(parameter)
    expect(parameter).to have_attributes(
      :name          => "image_id",
      :label         => "Image", # String#titleize removes trailing id
      :description   => "ID of the image to use for the instance to be created.",
      :data_type     => match(/[sS]tring/),
      :default_value => "F18-x86_64-cfntools",
      :hidden        => false,
      :required      => true
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(1)
    expect(constraints[0]).to be_a ::OrchestrationTemplate::OrchestrationParameterAllowed
    expect(constraints[0]).to be_kind_of ::OrchestrationTemplate::OrchestrationParameterConstraint
    expect(constraints[0]).to have_attributes(
      :description    => "Image ID must be either F18-i386-cfntools or F18-x86_64-cfntools.",
      :allowed_values => ["F18-i386-cfntools", "F18-x86_64-cfntools"]
    )
  end

  def assert_min_max_value(parameter)
    expect(parameter).to have_attributes(
      :name          => "db_port",
      :label         => "Port Number",  # provided by template
      :description   => "Database port number",
      :data_type     => match(/[nN]umber/),
      :default_value => "50000",
      :hidden        => false,
      :required      => true
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(2)
    expect(constraints[0]).to be_a ::OrchestrationTemplate::OrchestrationParameterPattern
    expect(constraints[1]).to be_a ::OrchestrationTemplate::OrchestrationParameterRange
    expect(constraints[1]).to be_kind_of ::OrchestrationTemplate::OrchestrationParameterConstraint
    expect(constraints[1]).to have_attributes(
      :description => "Port number must be between 40000 and 60000",
      :min_value   => 40_000,
      :max_value   => 60_000
    )
  end

  def assert_hidden_length_patterns(parameter)
    expect(parameter).to have_attributes(
      :name          => "admin_pass",
      :label         => "Admin Pass",
      :description   => "Admin password",
      :data_type     => match(/[sS]tring/),
      :default_value => nil,
      :hidden        => true,
      :required      => true
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(2)

    constraints.each do |constraint|
      expect(constraint).to be_kind_of ::OrchestrationTemplate::OrchestrationParameterConstraint
      if constraint.kind_of?(::OrchestrationTemplate::OrchestrationParameterLength)
        expect(constraint).to have_attributes(
          :description => match(/Admin password must be between 6 and 8 characters long./),
          :min_length  => 6,
          :max_length  => 8
        )
      elsif constraint.kind_of?(::OrchestrationTemplate::OrchestrationParameterPattern)
        expect(constraint).to have_attributes(
          :description => match(/Password must consist of characters and numbers only/),
          :pattern     => "[a-zA-Z0-9]+"
        )
      else
        raise "unexpected constraint type #{constraint.class.name}"
      end
    end
  end

  def assert_json_type(parameter)
    expect(parameter).to have_attributes(
      :name        => "metadata",
      :label       => "Metadata",
      :description => nil,
      :data_type   => "json",
      :hidden      => false,
      :required    => true,
    )
    expect(JSON.parse(parameter.default_value)).to eq('ver' => 'test')
    constraints = parameter.constraints
    expect(constraints.size).to eq(1)
    expect(constraints[0]).to be_a ::OrchestrationTemplate::OrchestrationParameterMultiline
    expect(constraints[0]).to be_kind_of ::OrchestrationTemplate::OrchestrationParameterConstraint
  end

  def assert_boolean_type(parameter)
    expect(parameter).to have_attributes(
      :name          => "skip_failed",
      :label         => "Skip Failed",
      :description   => nil,
      :data_type     => "boolean",
      :default_value => true,
      :hidden        => false,
      :required      => true,
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(1)
    expect(constraints[0]).to be_a ::OrchestrationTemplate::OrchestrationParameterBoolean
    expect(constraints[0]).to be_kind_of ::OrchestrationTemplate::OrchestrationParameterConstraint
  end

  def assert_list_type(parameter)
    expect(parameter).to have_attributes(
      :name          => 'subnets',
      :description   => 'Subnet IDs',
      :data_type     => 'List<AWS::EC2::Subnet::Id>',
      :default_value => "subnet-123a351e\nsubnet-123a351f",
      :required      => true
    )
  end

  def assert_aws_type(parameter)
    expect(parameter).to have_attributes(
      :name          => 'my_key_pair',
      :description   => 'Amazon EC2 key pair',
      :data_type     => 'AWS::EC2::KeyPair::KeyName',
      :default_value => 'my-key',
      :required      => true
    )
  end

  describe '#validate_format' do
    it 'passes validation if no content' do
      template = described_class.new
      expect(template.validate_format).to be_nil
    end

    it 'passes validation with correct YAML content' do
      expect(yaml_template.validate_format).to be_nil
    end

    it 'passes validation with correct JSON content' do
      expect(json_template.validate_format).to be_nil
    end

    it 'fails validations with incorrect YAML content' do
      template = described_class.new(:content => ":-Invalid:\n-String")
      expect(template.validate_format).not_to be_nil
    end

    it 'fails validations with incorrect JSON content' do
      template = described_class.new(:content => '{"Invalid:String')
      expect(template.validate_format).not_to be_nil
    end
  end

  describe '#deployment_options' do
    it do
      options = subject.deployment_options
      assert_deployment_option(options[0], "tenant_name", :OrchestrationParameterAllowedDynamic, true)
      assert_deployment_option(options[1], "stack_name", :OrchestrationParameterPattern, true)
      assert_deployment_option(options[2], "stack_onfailure", :OrchestrationParameterAllowed, false)
      assert_deployment_option(options[3], "stack_timeout", nil, false, 'integer')
    end
  end

  def assert_deployment_option(option, name, constraint_type, required, data_type = 'string')
    expect(option.name).to eq(name)
    expect(option.data_type).to eq(data_type)
    expect(option.required?).to eq(required)
    expect(option.constraints[0]).to be_kind_of("::OrchestrationTemplate::#{constraint_type}".constantize) if constraint_type
  end
end
