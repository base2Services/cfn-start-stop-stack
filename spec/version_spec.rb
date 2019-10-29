require 'cfn_manage/version'

describe 'Version' do
  it 'is version 0.8.0' do
    expect(CfnManage::VERSION).to eq("0.8.0")
  end
end
