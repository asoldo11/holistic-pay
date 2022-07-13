{{/*
Expand the name of the chart.
*/}}
{{- define "cms-interface.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cms-interface.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Liquibase image repository
*/}}
{{- define "cms-interface.liquibase.repository" -}}
{{- $liquiRepo := "liquibase/liquibase:4.9.1" }}
{{- $reg := default .Values.image.registry .Values.image.liquibase.registry }}
{{- if $reg }}
{{- printf "%s/%s" $reg $liquiRepo }}
{{- else }}
{{- $liquiRepo }}
{{- end }}
{{- end }}

{{/*
Liquibase image pull policy
*/}}
{{- define "cms-interface.liquibase.imagePullPolicy" -}}
{{- $reg := default .Values.image.pullPolicy .Values.image.liquibase.pullPolicy }}
{{- default "IfNotPresent" $reg }}
{{- end }}

{{/*
cms-interface image repository
*/}}
{{- define "cms-interface.app.repository" -}}
{{- $psRepo := "hrvestigo/cms-interface-ms" }}
{{- $reg := default .Values.image.registry .Values.image.app.registry }}
{{- if $reg }}
{{- printf "%s/%s" $reg $psRepo }}
{{- else }}
{{- $psRepo }}
{{- end }}
{{- end }}

{{/*
cms-interface image pull policy
*/}}
{{- define "cms-interface.app.imagePullPolicy" -}}
{{- $reg := default .Values.image.pullPolicy .Values.image.app.pullPolicy }}
{{- default "IfNotPresent" $reg }}
{{- end }}

{{/*
Liquibase run command
*/}}
{{- define "cms-interface.liquibase.command" -}}
{{- if .Values.enableLiquibase }}
{{- $secretFileName := required "Liquibase secret file name is required, please specify in secret.liquibase.secret.fileName" .Values.secret.liquibase.secret.fileName }}
{{- $secretFile := printf "%s%s" "/liquibase/secret/" $secretFileName }}
{{- $lsm := printf "%s%s%s" "cp /liquibase/changelog/liquibase.properties /tmp && sed -i \"s/__LIQUIBASE_PASSWORD__/$(cat " $secretFile ")/g\" /tmp/liquibase.properties && " }}
{{- $cmd := "/liquibase/docker-entrypoint.sh --changeLogFile=changelog.yaml --defaultsFile=/tmp/liquibase.properties --classpath=/liquibase/changelog:lib/postgresql-42.3.2.jar update" }}
{{- printf "%s%s" $lsm $cmd }}
{{- end }}
{{- end }}

{{/*
Trust store env variables
*/}}
{{- define "cms-interface.trustStoreEnv" -}}
{{- $trustStoreLocation := "/mnt/k8s/trust-store/" }}
{{- if .Values.mountTrustStoreFromSecret.enabled -}}
{{- $trustStoreName := required "Please specify trust store file name in mountTrustStoreFromSecret.trustStoreName" .Values.mountTrustStoreFromSecret.trustStoreName }}
{{- $trustStorePath := printf "%s%s" $trustStoreLocation $trustStoreName -}}
- name: SPRING_KAFKA_PROPERTIES_SSL_TRUSTSTORE_TYPE
  value: {{ required "Please specify trust store type in mountTrustStoreFromSecret.trustStoreType" .Values.mountTrustStoreFromSecret.trustStoreType }}
- name: SPRING_KAFKA_PROPERTIES_SSL_TRUSTSTORE_LOCATION
  value: {{ $trustStorePath }}
- name: SSL_TRUST_STORE_FILE
  value: {{ $trustStorePath }}
- name: JAVAX_NET_SSL_TRUST_STORE
  value: {{ $trustStorePath }}
{{- else if .Values.mountCaFromSecret.enabled -}}
{{- $trustStorePath := printf "%s%s" $trustStoreLocation "cacerts" -}}
- name: SPRING_KAFKA_PROPERTIES_SSL_TRUSTSTORE_LOCATION
  value: {{ $trustStorePath }}
- name: SSL_TRUST_STORE_FILE
  value: {{ $trustStorePath }}
- name: JAVAX_NET_SSL_TRUST_STORE
  value: {{ $trustStorePath }}
- name: SSL_TRUST_STORE_TYPE
  value: JKS
{{- end -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cms-interface.labels" -}}
helm.sh/chart: {{ include "cms-interface.chart" . }}
app: {{ include "cms-interface.name" . }}
project: HolisticPay
{{ include "cms-interface.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cms-interface.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cms-interface.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Volumes
*/}}
{{- define "cms-interface.volumes" -}}
{{- with .Values.customVolumes -}}
{{- toYaml . | default "" }}
{{ "" }}
{{- end -}}
- name: {{ include "cms-interface.name" . }}-secret
  secret:
    secretName: {{ include "cms-interface.name" . }}-secret
    items:
      - path: password.conf
        key: password.conf
- name: {{ include "cms-interface.name" . }}-configmap
  configMap:
    name: {{ include "cms-interface.name" . }}-configmap
- name: liquibase-config
  configMap:
    name: {{ include "cms-interface.name" . }}-liquibase-configmap
- name: server-cert
{{- if .Values.mountServerCertFromSecret.enabled }}
  secret:
    secretName: {{ .Values.mountServerCertFromSecret.secretName }}
{{- if and .Values.mountServerCertFromSecret.certPath .Values.mountServerCertFromSecret.keyPath }}
    items:
      - path: {{ .Values.mountServerCertFromSecret.certPath }}
        key: {{ .Values.mountServerCertFromSecret.certPath }}
      - path: {{ .Values.mountServerCertFromSecret.keyPath }}
        key: {{ .Values.mountServerCertFromSecret.keyPath }}
{{- end }}
{{- else }}
  emptyDir:
    medium: "Memory"
{{- end }}
{{- if .Values.mountKeyStoreFromSecret.enabled }}
- name: keystore
  secret:
    secretName: {{ .Values.mountKeyStoreFromSecret.secretName }}
{{- if .Values.mountKeyStoreFromSecret.keyStoreName }}
    items:
      - path: {{ .Values.mountKeyStoreFromSecret.keyStoreName }}
        key: {{ .Values.mountKeyStoreFromSecret.keyStoreName }}
{{- end }}
{{- end }}
{{- if .Values.mountTrustStoreFromSecret.enabled }}
- name: truststore
  secret:
    secretName: {{ .Values.mountTrustStoreFromSecret.secretName }}
{{- if .Values.mountTrustStoreFromSecret.trustStoreName }}
    items:
      - path: {{ .Values.mountTrustStoreFromSecret.trustStoreName }}
        key: {{ .Values.mountTrustStoreFromSecret.trustStoreName }}
{{- end }}
{{- else if .Values.mountCaFromSecret.enabled }}
- name: truststore
  secret:
    secretName: {{ required "Secret name is required when mounting CA from secret, please specify in mountCaFromSecret.secretName" .Values.mountCaFromSecret.secretName }}
{{- end }}
{{- if and .Values.logger.logDirMount.enabled .Values.logger.logDirMount.spec }}
- name: logdir
{{- toYaml .Values.logger.logDirMount.spec | nindent 2 }}
{{- end }}
{{- if .Values.enableLiquibase }}
- name: liquibase-secret
  secret:
    secretName: {{ required "Liquibase secret name is required, please specify in secret.liquibase.secret.secretName" .Values.secret.liquibase.secret.secretName }}
{{- if .Values.secret.liquibase.secret.fileName }}
    items:
      - path: {{ .Values.secret.liquibase.secret.fileName }}
        key: {{ .Values.secret.liquibase.secret.fileName }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Mounts for cms-interface application
*/}}
{{- define "cms-interface.mounts" -}}
{{- with .Values.customMounts -}}
{{- toYaml . | default "" }}
{{ "" }}
{{- end -}}
- mountPath: /mnt/k8s/secrets/
  name: {{ include "cms-interface.name" . }}-secret
- mountPath: /usr/app/config
  name: {{ include "cms-interface.name" . }}-configmap
{{- if .Values.mountServerCertFromSecret.enabled }}
- mountPath: /mnt/k8s/tls-server/key.pem
  name: server-cert
{{- if .Values.mountServerCertFromSecret.keyPath }}
  subPath: {{ .Values.mountServerCertFromSecret.keyPath }}
{{- end }}
- mountPath: /mnt/k8s/tls-server/cert.pem
  name: server-cert
{{- if .Values.mountServerCertFromSecret.certPath }}
  subPath: {{ .Values.mountServerCertFromSecret.certPath }}
{{- end }}
{{- else }}
- mountPath: /mnt/k8s/tls-server
  name: server-cert
{{- end }}
{{- if .Values.mountKeyStoreFromSecret.enabled }}
- mountPath: /mnt/k8s/key-store
  name: keystore
{{- end }}
{{- if .Values.mountTrustStoreFromSecret.enabled }}
- mountPath: /mnt/k8s/trust-store
  name: truststore
{{- else if .Values.mountCaFromSecret.enabled }}
- mountPath: /mnt/k8s/client-certs
  name: truststore
{{- end }}
{{- if and .Values.logger.logDirMount.enabled .Values.logger.logDirMount.spec }}
- mountPath: {{ .Values.logger.logDir }}
  name: logdir
{{- end}}
{{- end }}

{{/*
Application secrets
*/}}
{{- define "cms-interface.passwords" -}}
{{ tpl (.Files.Get "config/password.conf") . | b64enc }}
{{- end }}

{{/*
Application logger
*/}}
{{- define "cms-interface.logger" -}}
{{ tpl (.Files.Get "config/log4j2.xml") . }}
{{- end }}
