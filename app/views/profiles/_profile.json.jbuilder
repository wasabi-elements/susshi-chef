json.extract! profile, :id, :ShellLogin, :LoggingMask, :MaxSessionSeconds, :MaxSessionIdleSeconds, :SSHAgentForward, :SSHX11Forward, :SSHInteractive, :SSHSecureCopy, :SSHSessionSubsystems, :SSHSessionSubsystems, :SSHRemoteForwards, :SSHCommandExecs, :SSHTcpForwardSsh, :TargetHostKeyLearning, :created_at, :updated_at
json.url profile_url(profile, format: :json)
