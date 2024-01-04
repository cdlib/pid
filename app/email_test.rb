require 'mail'

# Set your SES SMTP credentials
smtp_username = ENV['SMTP_USERNAME']
smtp_password = ENV['SMTP_PASSWORD']

# Set SES SMTP server and port
ses_smtp_server = 'email-smtp.us-west-2.amazonaws.com'
ses_smtp_port = 587

# Specify the sender's email address
from_email = 'pid-no-reply@cdlib.org'

# Specify the recipient's email address
to_email = 'lam.pham@ucop.edu'

# Specify the subject and body of the email
subject = 'PID EMAIL TEST'
body = 'Hello, this is the body of your email.'

# Configure SES SMTP settings
Mail.defaults do
  delivery_method :smtp, {
    address: ses_smtp_server,
    port: ses_smtp_port,
    user_name: smtp_username,
    password: smtp_password,
    authentication: :login,
    enable_starttls_auto: true,
    openssl_verify_mode: 'none'
  }
end

# Build the email message
mail = Mail.new do
    from from_email
    to to_email
    subject subject
    body body
  end

# Send the email
begin
  mail.deliver!
  puts "Email sent!"
rescue StandardError => e
  puts "Error sending email: #{e.message}"
end