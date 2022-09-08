describe ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair do
  let(:ems) { FactoryBot.create(:ems_openstack_with_authentication) }
  let(:key_pair_attributes) {
    {
      :name        => "key1",
      :fingerprint => "0000",
      :public_key  => "AAA...B",
      :private_key => "BBB...C"
    }
  }
  let(:the_raw_key_pair) do
    double.tap do |key_pair|
      allow(key_pair).to receive(:name).and_return('key1')
      allow(key_pair).to receive(:fingerprint).and_return('0000')
      allow(key_pair).to receive(:public_key).and_return('AAA...B')
      allow(key_pair).to receive(:private_key).and_return('BBB...C')
    end
  end

  describe 'key pair create and delete' do
    it 'creates new key pair in nova' do
      service = double
      key_pairs = double
      allow(ExtManagementSystem).to receive(:find).with(ems.id).and_return(ems)
      allow(ems).to receive(:connect).with({:service => 'Compute'}).and_return(service)
      allow(service).to receive(:key_pairs).and_return(key_pairs)
      allow(key_pairs).to receive(:create).with(key_pair_attributes).and_return(
        the_raw_key_pair)
      subject.class.create_key_pair(ems.id, key_pair_attributes)
    end

    it 'deletes existing key pair from nova' do
      service = double
      subject.name = 'key1'
      subject.resource = ems
      allow(ems).to receive(:connect).with({:service => 'Compute'}).and_return(service)
      allow(service).to receive(:delete_key_pair).with('key1')
      subject.delete_key_pair
    end
  end

  describe 'validations' do
    it 'ems supports auth_key_pair_create' do
      expect(ems.class_by_ems("AuthKeyPair").supports?(:create)).to be_truthy
    end
  end
end
