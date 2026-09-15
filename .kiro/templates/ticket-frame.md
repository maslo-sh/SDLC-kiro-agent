# Ticket Frame (TASK-1)

id: FRAME-007
title: Payment webhook handler is not idempotent on retry
type: bug
severity: high
effort: M
confidence: high
status: framed
source_markers:
  - internal/payments/webhook.go:142  # TODO: guard against duplicate delivery
owner_agent: researcher
created: 2026-09-09