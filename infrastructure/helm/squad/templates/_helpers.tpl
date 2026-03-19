{{/*
=============================================================================
_helpers.tpl — Template helpers for the Squad Helm chart
=============================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "squad.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "squad.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart label value.
*/}}
{{- define "squad.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "squad.labels" -}}
helm.sh/chart: {{ include "squad.chart" . }}
{{ include "squad.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: squad
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "squad.selectorLabels" -}}
app.kubernetes.io/name: {{ include "squad.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Ralph-specific labels.
*/}}
{{- define "squad.ralph.labels" -}}
{{ include "squad.labels" . }}
app.kubernetes.io/component: ralph
squad.github.com/agent: ralph
squad.github.com/role: monitor
{{- end }}

{{/*
Ralph selector labels.
*/}}
{{- define "squad.ralph.selectorLabels" -}}
{{ include "squad.selectorLabels" . }}
app.kubernetes.io/component: ralph
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "squad.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "squad.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Secret name for credentials.
*/}}
{{- define "squad.secretName" -}}
{{- if .Values.credentials.existingSecret }}
{{- .Values.credentials.existingSecret }}
{{- else }}
{{- include "squad.fullname" . }}-credentials
{{- end }}
{{- end }}

{{/*
ConfigMap name for squad config.
*/}}
{{- define "squad.configMapName" -}}
{{- include "squad.fullname" . }}-config
{{- end }}
