require 'cfn_manage/version'

describe 'Version' do
  it 'is version 0.5.4' do
    expect(CfnManage::VERSION).to eq("0.5.4")
  end
end
