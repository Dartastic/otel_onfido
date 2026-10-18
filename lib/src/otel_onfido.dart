// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_onfido_suppression.dart';

const _tracerName = 'dartastic_otel_libs_onfido';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class OnfidoResult {
  const OnfidoResult({
    this.checkId,
    this.applicantId,
    this.checkStatus,
    this.checkResult,
    this.reportNames,
    this.subResult,
    this.documentType,
    this.workflowRunId,
    this.region,
    this.requestId,
    this.statusCode,
  });

  /// `id` for check creates.
  final String? checkId;

  /// `applicant_id`.
  final String? applicantId;

  /// `in_progress` / `awaiting_applicant` / `complete` / `withdrawn` /
  /// `paused` / `reopened`.
  final String? checkStatus;

  /// Final outcome: `clear` / `consider` / `unidentified` / `null`
  /// (not yet decided).
  final String? checkResult;

  /// Comma-joined report names selected — drives per-check cost since
  /// Onfido bills per report (document, facial_similarity, watchlist,
  /// proof_of_address, etc.).
  final String? reportNames;

  /// `clear` / `rejected` / `suspected` / `caution` — finer-grained
  /// failure category on `consider` outcomes.
  final String? subResult;

  /// `passport` / `driving_licence` / `national_identity_card` /
  /// `residence_permit`.
  final String? documentType;

  /// Workflow run id when triggered via Onfido Studio workflow.
  final String? workflowRunId;

  /// `eu` / `us` / `ca` — Onfido regional endpoint (data residency).
  final String? region;

  /// `X-Onfido-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class OnfidoCallResult<T> {
  const OnfidoCallResult({required this.value, this.result});
  final T value;
  final OnfidoResult? result;
}

/// Wraps an Onfido API call in a CLIENT span. [operation] is one of
/// `applicants.list`, `applicants.create`, `applicants.update`,
/// `applicants.delete`, `documents.upload`, `documents.list`,
/// `live_photos.upload`, `live_videos.list`, `checks.create`,
/// `checks.get`, `checks.list`, `reports.get`, `workflow_runs.create`,
/// `workflow_runs.get`, `sdk_token.generate`, `webhooks.list`,
/// `webhooks.create`.
Future<T> tracedOnfido<T>({
  required String operation,
  required Future<OnfidoCallResult<T>> Function() invoke,
  String? region,
}) async {
  if (onfidoInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'onfido',
    'rpc.method': operation,
    'onfido.operation': operation,
  };
  if (region != null) m['onfido.region'] = region;

  final span = _tracer().startSpan(
    'onfido $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.checkId != null) {
        extras.add(OTelAPI.attributeString(
          'onfido.check.id',
          r.result!.checkId!,
        ));
      }
      if (r.result!.applicantId != null) {
        extras.add(OTelAPI.attributeString(
          'onfido.applicant.id',
          r.result!.applicantId!,
        ));
      }
      if (r.result!.checkStatus != null) {
        extras.add(OTelAPI.attributeString(
          'onfido.check.status',
          r.result!.checkStatus!,
        ));
      }
      if (r.result!.checkResult != null) {
        extras.add(OTelAPI.attributeString(
          'onfido.check.result',
          r.result!.checkResult!,
        ));
        if (r.result!.checkResult == 'consider' ||
            r.result!.checkResult == 'unidentified') {
          span.setStatus(
            SpanStatusCode.Error,
            'Onfido check ${r.result!.checkResult}',
          );
        }
      }
      if (r.result!.reportNames != null) {
        extras.add(OTelAPI.attributeString(
          'onfido.reports',
          r.result!.reportNames!,
        ));
      }
      if (r.result!.subResult != null) {
        extras.add(OTelAPI.attributeString(
          'onfido.check.sub_result',
          r.result!.subResult!,
        ));
      }
      if (r.result!.documentType != null) {
        extras.add(OTelAPI.attributeString(
          'onfido.document.type',
          r.result!.documentType!,
        ));
      }
      if (r.result!.workflowRunId != null) {
        extras.add(OTelAPI.attributeString(
          'onfido.workflow_run.id',
          r.result!.workflowRunId!,
        ));
      }
      if (r.result!.region != null) {
        extras.add(OTelAPI.attributeString(
          'onfido.region',
          r.result!.region!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'onfido.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Onfido HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
