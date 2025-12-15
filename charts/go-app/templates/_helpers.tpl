{{- define "go-app.name" -}}
go-app
{{- end }}

{{- define "go-app.fullname" -}}
{{ include "go-app.name" . }}
{{- end }}
