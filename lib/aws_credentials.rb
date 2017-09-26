require 'aws-sdk'

module Base2

  class AWSCredentials

    def self.get_session_credentials(session_name)

      #check if AWS_ASSUME_ROLE exists
      session_name =  "#{session_name.gsub('_','-')}-#{Time.now.getutc.to_i}"
      if session_name.length > 64
        session_name = session_name[-64..-1]
      end
      assume_role = ENV['AWS_ASSUME_ROLE'] or nil
      if not assume_role.nil?
        return Aws::AssumeRoleCredentials.new(
            role_arn: assume_role,
            role_session_name: session_name
        )
      end

      # check if explicitly set shared credentials profile
      if ENV.key?('CFN_AWS_PROFILE')
        return Aws::SharedCredentials.new(profile_name: ENV['CFN_AWS_PROFILE'])
      end

      # check if Instance Profile available
      credentials = Aws::InstanceProfileCredentials.new(retries: 2, http_open_timeout:1)
      return credentials unless credentials.credentials.access_key_id.nil?

      # use default profile
      return Aws::SharedCredentials.new()

    end
  end
end