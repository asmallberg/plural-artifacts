secrets:
  redis_password: {{ dedupe . "airflow.secrets.redis_password" (randAlphaNum 14) }}

sshConfig:
{{ if and (hasKey . "airflow") (hasKey .airflow "sshConfig") }}
  id_rsa: {{ .airflow.sshConfig.id_rsa | quote }}
  id_rsa_pub: {{ .airflow.sshConfig.id_rsa_pub | quote }}
{{ else if .Values.hostname }}
  {{ $id_rsa := readLineDefault "Enter the path to your deploy keys" (homeDir ".ssh" "id_rsa") }}
  id_rsa: {{ readFile $id_rsa | quote }}
  id_rsa_pub: {{ readFile (printf "%s.pub" $id_rsa) | quote }}
{{ else }}
  id_rsa: example
  id_rsa_pub: example
{{ end }}

postgresqlPassword: {{ dedupe . "airflow.postgresqlPassword" (randAlphaNum 20) }}

{{ $hostname := default "example.com" .Values.hostname }}
airflow:
  web:
    baseUrl: {{ $hostname }}
    {{ if .OIDC }}
    webserverConfig:
      stringOverride: |-
        import jwt
        from airflow import configuration as conf
        from airflow.www.security import AirflowSecurityManager
        from flask_appbuilder.security.manager import AUTH_OAUTH

        class PluralSecurityManager(AirflowSecurityManager):
          def _get_oauth_user_info(self, provider, response):
              if provider == "plural":
                  me = self._azure_jwt_token_parse(response["id_token"])
                  split_name = me["name"].split()
                  return {
                      "username": me["name"],
                      "name": me["name"],
                      "first_name": split_name[0],
                      "last_name": " ".join(split_name[1:]),
                      "email": me["email"],
                      "role_keys": [],
                  }
              else:
                  return {}
          oauth_user_info = _get_oauth_user_info
        
        SECURITY_MANAGER_CLASS = PluralSecurityManager

        SQLALCHEMY_DATABASE_URI = conf.get('core', 'SQL_ALCHEMY_CONN')
        
        AUTH_TYPE = AUTH_OAUTH
        
        # registration configs
        AUTH_USER_REGISTRATION = True  # allow users who are not already in the FAB DB
        AUTH_USER_REGISTRATION_ROLE = "User"  # this role will be given in addition to any AUTH_ROLES_MAPPING

        # the list of providers which the user can choose from
        OAUTH_PROVIDERS = [
            {
                'name': 'plural',
                'icon': 'fa-openid',
                'token_key': 'access_token',
                'remote_app': {
                    'client_id': '{{ .OIDC.ClientId }}',
                    'client_secret': '{{ .OIDC.ClientSecret }}',
                    'api_base_url': '{{ .OIDC.Configuration.Issuer }}oauth2/',
                    'client_kwargs': {
                        'scope': 'openid'
                    },
                    'redirect_uri': 'https://{{ $hostname }}/oauth-authorized/plural',
                    'access_token_url': '{{ .OIDC.Configuration.TokenEndpoint }}',
                    'authorize_url': '{{ .OIDC.Configuration.AuthorizationEndpoint }}',
                    'token_endpoint_auth_method': 'client_secret_post',
                }
            }
        ]
        
        # force users to re-auth after 30min of inactivity (to keep roles in sync)
        PERMANENT_SESSION_LIFETIME = 1800
  {{ end }}
  ingress:
    web:
      host: {{ $hostname }}

  fernetKey: {{ dedupe . "airflow.airflow.fernetKey" (randAlphaNum 20)}}

  airflow:
    config:
      AIRFLOW__WEBSERVER__BASE_URL: https://{{ $hostname }}/
    {{ if eq .Provider "google" }}
      AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER: "gs://{{ .Values.airflowBucket }}/airflow/logs"
    {{ end }}
    {{ if eq .Provider "aws" }}
      AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER: "s3://{{ .Values.airflowBucket }}/airflow/logs"
    {{ end }}
    users:
    - username: {{ .Values.adminUsername }}
      password: CHANGEME
      role: Admin
      email: {{ .Values.adminEmail }}
      firstName: {{ .Values.adminFirst }}
      lastName: {{ .Values.adminLast }}
  
    {{ if eq .Provider "google" }}
    connections:
    ## see docs: https://airflow.apache.org/docs/apache-airflow-providers-google/stable/connections/gcp.html
    - id: my_gcp
      type: google_cloud_platform
      description: my GCP connection
      extra: |-
        { "extra__google_cloud_platform__num_retries": "5" }
    {{ end }}

  serviceAccount:
  {{ if eq .Provider "google" }}
    create: false
  {{ end }}
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::{{ .Project }}:role/{{ .Cluster }}-airflow"

  dags:
    gitSync:
      enabled: true
      repo: {{ .Values.dagRepo }}
      branch: {{ .Values.branchName }}
      revision: HEAD
      syncWait: 60
      sshSecret: airflow-ssh-config
      sshSecretKey: id_rsa
      sshKnownHosts: {{ knownHosts | quote }}