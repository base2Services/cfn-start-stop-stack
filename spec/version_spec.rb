require 'cfn_manage/version'

describe 'Version' do
  it 'is version 0.5.2' do
    expect(CfnManage::VERSION).to eq("0.5.2")
  end
end
