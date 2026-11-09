{{/* Couple every Python dispatcher's dial to the TypeScript worker role.
     Direct pod env also rolls the dispatchers when the toggle changes. */}}
{{- define "llamacloud.parseWorkflow.env" }}
{{- if ((.Values.config).parse).multiActivityWorkflowEnabled }}
- name: MULTI_ACTIVITY_WORKFLOW_PERCENTAGE
  value: "100"
{{- end }}
{{- end }}
