// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_onfido/otel_onfido.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_onfido-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('checks.create records reports + region + document', () async {
    await tracedOnfido<String>(
      operation: 'checks.create',
      region: 'eu',
      invoke: () async => const OnfidoCallResult(
        value: 'ok',
        result: OnfidoResult(
          checkId: 'chk-1',
          applicantId: 'app-1',
          checkStatus: 'in_progress',
          reportNames: 'document,facial_similarity_photo,watchlist_standard',
          documentType: 'passport',
          region: 'eu',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('onfido checks.create')!);
    expect(a['onfido.check.id'], 'chk-1');
    expect(a['onfido.applicant.id'], 'app-1');
    expect(a['onfido.reports'],
        'document,facial_similarity_photo,watchlist_standard');
    expect(a['onfido.region'], 'eu');
    expect(a['onfido.document.type'], 'passport');
  });

  test('consider result sets span error', () async {
    await tracedOnfido<String>(
      operation: 'checks.get',
      invoke: () async => const OnfidoCallResult(
        value: 'ok',
        result: OnfidoResult(
          checkStatus: 'complete',
          checkResult: 'consider',
          subResult: 'rejected',
        ),
      ),
    );
    final s = spans.findSpanByName('onfido checks.get')!;
    expect(s.status, SpanStatusCode.Error);
    final a = attrsOf(s);
    expect(a['onfido.check.sub_result'], 'rejected');
  });

  test('suppression skips spans', () async {
    await runWithoutOnfidoInstrumentationAsync(() async {
      await tracedOnfido<String>(
        operation: 'applicants.list',
        invoke: () async => const OnfidoCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('onfido '), isEmpty);
  });
}
