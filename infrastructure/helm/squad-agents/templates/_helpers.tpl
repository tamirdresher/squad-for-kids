{{/*
=============================================================================
_helpers.tpl — Template helpers for squad-agents Helm chart
=============================================================================
*/}}

{{/*
Expand the chart name.
*/}}
{{- define "squad-agents.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "squad-agents.fullname" -}}
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
Chart label.
*/}}
{{- define "squad-agents.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "squad-agents.labels" -}}
helm.sh/chart: {{ include "squad-agents.chart" . }}
{{ include "squad-agents.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
squad.github.com/repository: {{ .Values.global.repository | quote }}
{{- end }}

{{/*
Selector labels (stable — used in matchLabels).
*/}}
{{- define "squad-agents.selectorLabels" -}}
app.kubernetes.io/name: {{ include "squad-agents.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "squad-agents.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "squad-agents.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Full image reference for a given agent config (ralph or picard).
Usage: include "squad-agents.imageRef" (dict "Values" .Values "agent" .Values.ralph)
*/}}
{{- define "squad-agents.imageRef" -}}
{{- $acr := .Values.global.acrLoginServer -}}
{{- $repo := .agent.image.repository -}}
{{- $tag := .agent.image.tag -}}
{{- if $acr -}}
{{- printf "%s/%s:%s" $acr $repo $tag -}}
{{- else -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}
{{- end }}
