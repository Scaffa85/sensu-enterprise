{% set sensu_user = salt['pillar.get']('sensu_repo_user') -%}
{% set sensu_pass = salt['pillar.get']('sensu_repo_pass') -%}

sensu_enterprise_repo:
  pkgrepo.managed:
    - humanname: sensu-enterprise
    - baseurl: 'https://{{sensu_user}}:{{sensu_pass}}@enterprise.sensuapp.com/yum/noarch/'
    - gpgcheck: 0
    - enabled: 1

sensu_enterprise_dashboard_repo:
  pkgrepo.managed:
    - humanname: sensu-enterprise
    - baseurl: 'https://{{sensu_user}}:{{sensu_pass}}@enterprise.sensuapp.com/yum/\$basearch/'
    - gpgcheck: 0
    - enabled: 1

epel-release:
  pkg.installed: []

erlang:
    pkg.installed: []

redis:
    pkg.installed: []
    service.running:
      - enable: True

rabbitmq_rpm_key:
  cmd.run:
    - name: 'sudo rpm --import http://www.rabbitmq.com/rabbitmq-signing-key-public.asc'
    - unless:
      - 'rpm -qa | grep rabbit'

rabbit_rpm:
  cmd.run:
    - name: 'rpm -Uvh http://www.rabbitmq.com/releases/rabbitmq-server/v3.4.1/rabbitmq-server-3.4.1-1.noarch.rpm'
    - unless:
      - 'rpm -qa | grep rabbit'

rabbitmq-server:
  pkg.installed: []
  service.running:
    - enable: True

rabbit_config_vhost:
  cmd.run:
    - name: 'rabbitmqctl add_vhost /sensu'
    - unless: 'rabbitmqctl list_vhosts | grep "sensu"'

rabbit_config_user:
  cmd.run:
    - name: 'rabbitmqctl add_user sensu'
    - unless: 'rabbitmqctl list_users | grep "sensu"'

rabbit_set_user:
  rabbitmq_user.present:
    - name: sensu
    - password: {{ salt['pillar.get']('sensu_rabbit_pw') }}
    - perms:
      - '/sensu':
        - '.*'
        - '.*'
        - '.*'
      require:
        - rabbit_config_vhost

sensu_server:
  pkg.installed:
    - name: sensu-enterprise
  service.running:
    - name: sensu-enterprise
    - enable: True
    - require:
      - sensu_enterprise_repo

sensu_frontend:
  pkg.installed:
    - name: sensu-enterprise-dashboard
  service.running:
    - name: sensu-enterprise-dashboard
    - enable: True
    - watch:
      - file: /etc/sensu/dashboard.json
    - require:
      - sensu_enterprise_repo
      - sensu_enterprise_dashboard_repo
      - sensu_server
      - /etc/sensu/dashboard.json

/etc/sensu/conf.d/api.json:
  file.managed:
    - source: salt://sensu-enterprise/files/api.json.jinja
    - template: jinja
    - user: sensu
    - group: sensu
    - mode: 644
    - require:
      - sensu_server

/etc/sensu/conf.d/transport.json:
  file.managed:
    - source: salt://sensu-enterprise/files/transport.json
    - user: sensu
    - group: sensu
    - mode: 644
    - require:
      - sensu_server

/etc/sensu/conf.d/rabbitmq.json:
  file.managed:
    - source: salt://sensu-enterprise/files/rabbitmq.json.jinja
    - template: jinja
    - user: sensu
    - group: sensu
    - mode: 644
    - require:
      - sensu_server

/etc/sensu/dashboard.json:
  file.managed:
    - source: salt://sensu-enterprise/files/dashboard.json.jinja
    - template: jinja
    - user: sensu
    - group: sensu
    - mode: 644

enforcing:
  selinux.mode

nis_enabled:
  selinux.boolean:
    - value: True
    - persist: True

httpd_can_network_connect:  
  selinux.boolean:
    - value: True
    - persist: True

mod_ssl:
  pkg.installed: []

httpd:
  pkg.installed: []
  service.running:
    - enable: True
    - catch:
      - pkg: httpd
      - file: /etc/httpd/conf/httpd.conf
      - file: /etc/httpd/conf.d/*
      - user: httpd

  user.present:
    - uid: 87
    - gid: 87
    - home: /var/www/html
    - shell: /bin/nologin
    - require:
      - group: httpd
  group.present:
    - gid: 87
    - require:
      - pkg: httpd

/etc/httpd/conf/httpd.conf:
  file.managed:
    - source: salt://sensu-enterprise/files/httpd.conf
    - user: root
    - group: root
    - mode: 644

/etc/httpd/conf.d/apache2-sensu.conf:
  file.managed:
    - source: salt://sensu-enterprise/files/apache2-sensu.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644

mk_ssl_directory:
  cmd.run:
    - name: 'mkdir -p /etc/ssl/private/'
    - unless:
      - ls /etc/ssl/private/

/etc/ssl/private/wildcard_tvflab_co_uk.key:
  file.managed:
    - contents_pillar: wildcard_key
    - user: root
    - group: root
    - mode: 640
    - require:
      - httpd

/etc/ssl/certs/wildcard_tvflab_co_uk.crt:
  file.managed:
    - contents_pillar: wildcard_cert
    - user: root
    - group: root
    - mode: 644
    - require:
      - httpd
  

