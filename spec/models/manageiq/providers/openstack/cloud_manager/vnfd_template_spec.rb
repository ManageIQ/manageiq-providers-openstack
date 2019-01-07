describe ManageIQ::Providers::Openstack::CloudManager::VnfdTemplate do
  describe ".eligible_manager_types" do
    it "lists the classes of eligible managers" do
      described_class.eligible_manager_types.each do |klass|
        expect(klass <= ManageIQ::Providers::Openstack::CloudManager).to be_truthy
      end
    end
  end

  let(:valid_template) { FactoryBot.create(:vnfd_template_openstack_in_yaml) }

  describe '#validate_format' do
    it 'passes validation if no content' do
      template = described_class.new
      expect(template.validate_format).to be_nil
    end

    it 'passes validation with correct YAML content' do
      expect(valid_template.validate_format).to be_nil
    end

    it 'fails validations with incorrect YAML content' do
      template = described_class.new(:content => ":-Invalid:\n-String")
      expect(template.validate_format).not_to be_nil
    end
  end
end
