development:
  host: 127.0.0.1
  port: 22122
  pid_file: `pwd`/tmp/pids/starling_development.pid
  queue_path: `pwd`/tmp/starling
  timeout: 0
  syslog_channel: starling-tampopo
  log_level: DEBUG
  daemonize: true
  queue: development

test:
  host: 127.0.0.1
  port: 22122
  pid_file: `pwd`/tmp/pids/starling_test.pid
  queue_path: `pwd`/tmp/starling
  timeout: 0
  syslog_channel: starling-tampopo
  log_level: DEBUG
  daemonize: true
  queue: test

production:
  host: 127.0.0.1
  port: 22122
  pid_file: `pwd`/tmp/pids/starling_production.pid
  queue_path: `pwd`/tmp/starling
  timeout: 0
  syslog_channel: starling-tampopo
  log_level: DEBUG
  daemonize: true
  queue: production
