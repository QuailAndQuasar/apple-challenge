# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none

    # Add :unsafe_inline only in development
    if Rails.env.development?
      policy.script_src :self, :https, :unsafe_eval, :unsafe_inline, "https://maps.googleapis.com", "https://ajax.googleapis.com"
    else
      policy.script_src :self, :https, :unsafe_eval, "https://maps.googleapis.com", "https://ajax.googleapis.com"
    end

    policy.style_src   :self, :https, :unsafe_inline

    # Specify URI for violation reports
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted importmap and inline scripts
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)

  # Report violations without enforcing the policy.
  # config.content_security_policy_report_only = true
end 