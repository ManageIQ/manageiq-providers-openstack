class ManageIQ::Providers::Openstack::CloudManager::OrchestrationTemplate < ::OrchestrationTemplate
  def parameter_groups
    content_hash = parse
    raw_groups = content_hash["parameter_groups"] || content_hash["ParameterGroups"]

    if raw_groups
      indexed_parameters = parameters(content_hash).index_by(&:name)
      raw_groups.collect do |raw|
        OrchestrationTemplate::OrchestrationParameterGroup.new(
          :label       => raw["label"],
          :description => raw["description"],
          # Map each parameter name to its corresponding object
          :parameters  => raw["parameters"].collect { |name| indexed_parameters[name] }
        )
      end
    else
      # Create a single group to include all parameters
      [OrchestrationTemplate::OrchestrationParameterGroup.new(
        :label      => "Parameters",
        :parameters => parameters(content_hash)
      )]
    end
  end

  # Parsing parameters for both Hot and Cloudformation formats
  # Keys in Hot are lower case snake style,
  #   label, json, boolean, constraints are Hot only
  # Keys in Cloudformation are upper case camel style
  #   List<> is Cloudformation only
  def parameters(content_hash = nil)
    content_hash ||= parse
    (content_hash["parameters"] || content_hash["Parameters"] || {}).collect do |key, val|
      OrchestrationTemplate::OrchestrationParameter.new(
        :name          => key,
        :label         => val.key?('label') ? val['label'] : key.titleize,
        :data_type     => val['type'] || val['Type'],
        :default_value => parse_default_value(val),
        :description   => val['description'] || val['Description'],
        :hidden        => parse_hidden(val),
        :constraints   => ([constraint_from_type(val)] + parse_constraints(val)).compact,
        :required      => true
      )
    end
  end

  def deployment_options(_manager_class = nil)
    tenant_opt = OrchestrationTemplate::OrchestrationParameter.new(
      :name           => "tenant_name",
      :label          => "Tenant",
      :data_type      => "string",
      :description    => "Tenant where the stack will be deployed",
      :required       => true,
      :reconfigurable => false,
      :constraints    => [
        OrchestrationTemplate::OrchestrationParameterAllowedDynamic.new(
          :fqname => "/Cloud/Orchestration/Operations/Methods/Available_Tenants"
        )
      ]
    )

    onfailure_opt = OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "stack_onfailure",
      :label       => "On Failure",
      :data_type   => "string",
      :description => "Select what to do if stack creation failed",
      :constraints => [
        OrchestrationTemplate::OrchestrationParameterAllowed.new(
          :allowed_values => {'ROLLBACK' => 'Rollback', 'DO_NOTHING' => 'Do nothing'}
        )
      ]
    )

    timeout_opt = OrchestrationTemplate::OrchestrationParameter.new(
      :name        => "stack_timeout",
      :label       => "Timeout(minutes, optional)",
      :data_type   => "integer",
      :description => "Abort the creation if it does not complete in a proper time window",
    )

    [tenant_opt] + super << onfailure_opt << timeout_opt
  end

  def self.eligible_manager_types
    [ManageIQ::Providers::Openstack::CloudManager]
  end

  # return the parsing error message if not valid JSON or YAML; otherwise nil
  def validate_format
    return unless content
    return validate_format_json if format == 'json'
    validate_format_yaml
  end

  # quickly guess the format without full validation
  # returns either json or yaml
  def format
    content.strip.start_with?('{') ? 'json'.freeze : 'yaml'.freeze
  end

  def self.display_name(number = 1)
    n_('Heat Template', 'Heat Templates', number)
  end

  private

  def parse
    return JSON.parse(content) if format == 'json'
    YAML.safe_load(content, :permitted_classes => [Date])
  end

  def validate_format_yaml
    YAML.parse(content) && nil if content
  rescue Psych::SyntaxError => err
    err.message
  end

  def validate_format_json
    JSON.parse(content) && nil if content
  rescue JSON::ParserError => err
    err.message
  end

  def parse_default_value(parameter)
    raw_default = parameter['default'] || parameter['Default']
    case parameter['type'] || parameter['Type']
    when 'json'
      JSON.pretty_generate(raw_default || {'sample(please delete)' => 'JSON format'})
    when 'comma_delimited_list', 'CommaDelimitedList', /^List<.+>$/
      multiline_value_for_list(raw_default)
    when 'boolean'
      ([true, 1] + %w(t T y Y yes Yes YES true True TRUE 1)).include?(raw_default)
    else
      raw_default
    end
  end

  def multiline_value_for_list(val)
    return val.join("\n") if val.kind_of?(Array)
    return val.tr!(",", "\n") if val.kind_of?(String)
    "sample1(please delete)\nsample2(please delete)"
  end

  def parse_hidden(parameter)
    val = parameter.key?('hidden') ? parameter['hidden'] : parameter['NoEcho']
    return true if val == true || val == 'true'
    false
  end

  def constraint_from_type(parameter)
    case parameter['type'] || parameter['Type']
    when 'json'
      OrchestrationTemplate::OrchestrationParameterMultiline.new(
        :description => 'Parameter in JSON format'
      )
    when 'comma_delimited_list', 'CommaDelimitedList', /^List<.*>$/
      OrchestrationTemplate::OrchestrationParameterMultiline.new(
        :description => 'Parameter in list format'
      )
    when 'boolean'
      OrchestrationTemplate::OrchestrationParameterBoolean.new
    when 'number', 'Number'
      OrchestrationTemplate::OrchestrationParameterPattern.new(
        :pattern     => '^[+-]?([1-9]\d*|0)(\.\d+)?$',
        :description => 'Numeric parameter'
      )
    end
  end

  def parse_constraints(parameter)
    return parse_constraints_hot(parameter['constraints']) if parameter.key?('constraints')
    parse_constraints_cfn(parameter)
  end

  def parse_constraints_hot(raw_constraints)
    (raw_constraints || []).collect do |raw_constraint|
      if raw_constraint.key?('allowed_values')
        parse_allowed_values_hot(raw_constraint)
      elsif raw_constraint.key?('allowed_pattern')
        parse_pattern_hot(raw_constraint)
      elsif raw_constraint.key?('length')
        parse_length_constraint_hot(raw_constraint)
      elsif raw_constraint.key?('range')
        parse_value_constraint_hot(raw_constraint)
      elsif raw_constraint.key?('custom_constraint')
        parse_custom_constraint_hot(raw_constraint)
      else
        raise MiqException::MiqParsingError, _("Unknown constraint %{constraint}") % {:constraint => raw_constraint}
      end
    end
  end

  def parse_allowed_values_hot(hash)
    OrchestrationTemplate::OrchestrationParameterAllowed.new(
      :allowed_values => hash['allowed_values'],
      :description    => hash['description']
    )
  end

  def parse_pattern_hot(hash)
    OrchestrationTemplate::OrchestrationParameterPattern.new(
      :pattern     => hash['allowed_pattern'],
      :description => hash['description']
    )
  end

  def parse_length_constraint_hot(hash)
    OrchestrationTemplate::OrchestrationParameterLength.new(
      :min_length  => hash['length']['min'],
      :max_length  => hash['length']['max'],
      :description => hash['description']
    )
  end

  def parse_value_constraint_hot(hash)
    OrchestrationTemplate::OrchestrationParameterRange.new(
      :min_value   => hash['range']['min'],
      :max_value   => hash['range']['max'],
      :description => hash['description']
    )
  end

  def parse_custom_constraint_hot(hash)
    OrchestrationTemplate::OrchestrationParameterCustom.new(
      :custom_constraint => hash['custom_constraint'],
      :description       => hash['description']
    )
  end

  def parse_constraints_cfn(raw_constraints)
    constraints = []
    if raw_constraints.key?('AllowedValues')
      constraints << parse_allowed_values_cfn(raw_constraints)
    end
    if raw_constraints.key?('AllowedPattern')
      constraints << parse_pattern_cfn(raw_constraints)
    end
    if raw_constraints.key?('MinLength') || raw_constraints.key?('MaxLength')
      constraints << parse_length_constraint_cfn(raw_constraints)
    end
    if raw_constraints.key?('MinValue') || raw_constraints.key?('MaxValue')
      constraints << parse_value_constraint_cfn(raw_constraints)
    end
    constraints
  end

  def parse_allowed_values_cfn(hash)
    OrchestrationTemplate::OrchestrationParameterAllowed.new(
      :allowed_values => hash['AllowedValues'],
      :description    => hash['ConstraintDescription']
    )
  end

  def parse_pattern_cfn(hash)
    OrchestrationTemplate::OrchestrationParameterPattern.new(
      :pattern     => hash['AllowedPattern'],
      :description => hash['ConstraintDescription']
    )
  end

  def parse_length_constraint_cfn(hash)
    OrchestrationTemplate::OrchestrationParameterLength.new(
      :min_length  => hash['MinLength'].to_i,
      :max_length  => hash['MaxLength'].to_i,
      :description => hash['ConstraintDescription']
    )
  end

  def parse_value_constraint_cfn(hash)
    OrchestrationTemplate::OrchestrationParameterRange.new(
      :min_value   => hash['MinValue'].to_r,
      :max_value   => hash['MaxValue'].to_r,
      :description => hash['ConstraintDescription']
    )
  end
end
