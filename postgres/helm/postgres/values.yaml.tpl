configAwsOrGcp:
{{ if or (eq .Provider "aws") (eq .Provider "azure") (eq .Provider "equinix") (eq .Provider "kind") (eq .Provider "generic") }}
  wal_s3_bucket: {{ .Values.wal_bucket }}
{{ else if eq .Provider "google" }}
  additional_secret_mount: postgres-gcp-creds
  additional_secret_mount_path: "/var/secrets/google"

  wal_gs_bucket: {{ .Values.wal_bucket }}
  gcp_credentials: "/var/secrets/google/credentials.json"
{{ end }}

{{ if eq .Provider "aws" }}
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::{{ .Project }}:role/{{ .Cluster }}-postgres"
{{ end }}

provider: {{ .Provider }}

{{ $minioNamespace := namespace "minio" }}

configConfigMap:
  AWS_SDK_LOAD_CONFIG: "1"
  USE_WALG_BACKUP: "true"
  USE_WALG_RESTORE: "true"
  CLONE_USE_WALG_RESTORE: "true"
  {{- if eq .Provider "azure" }}
  AWS_S3_FORCE_PATH_STYLE: "true"
  AWS_ENDPOINT: {{ .Configuration.minio.hostname }}
  {{- end }}
  {{- if eq .Provider "equinix" }}
  AWS_S3_FORCE_PATH_STYLE: "true"
  AWS_ENDPOINT: {{ .Configuration.minio.hostname }}
  {{- end }}
  {{- if eq .Provider "kind" }}
  AWS_S3_FORCE_PATH_STYLE: "true"
  AWS_ENDPOINT: http://minio.{{ $minioNamespace }}:9000
  {{- end }}
  {{- if eq .Provider "generic" }}
  AWS_S3_FORCE_PATH_STYLE: "true"
  {{- if .ObjectStorage.Insecure }}
  AWS_ENDPOINT: https://{{ .ObjectStorage.Endpoint }}
  {{- else }}
  AWS_ENDPOINT: http://{{ .ObjectStorage.Endpoint }}
  {{- end }}
  {{- end }}

{{ if or (eq .Provider "azure") (eq .Provider "equinix") (eq .Provider "kind") (eq .Provider "generic") }}
configKubernetes:
  pod_environment_secret: plural-postgres-s3
{{ end }}

{{- if eq .Provider "aws" }}
configKubernetes:
  pod_service_account_definition: |
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      annotations:
        eks.amazonaws.com/role-arn: "arn:aws:iam::{{ .Project }}:role/{{ .Cluster }}-postgres"
{{- end }}

{{ if or (eq .Provider "azure") (eq .Provider "equinix") (eq .Provider "kind") (eq .Provider "generic") }}
configSecret:
  enabled: true
  env:
    AWS_ACCESS_KEY_ID: {{ importValue "Terraform" "access_key_id" }}
    AWS_SECRET_ACCESS_KEY: {{ importValue "Terraform" "secret_access_key" }}
{{ end }}
