require("syslog")

Syslog.open("ROV", Syslog::LOG_PID, Syslog::LOG_DAEMON | Syslog::LOG_LOCAL3)
Syslog.log(Syslog::LOG_NOTICE, "Ruby ROV Syslog process has started on #{Time.now}")

def log(msg = nil)
  Syslog.log(Syslog::LOG_CRIT, "[ROV] (#{Time.now}): #{msg}")
end
