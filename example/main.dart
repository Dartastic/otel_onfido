// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_onfido/otel_onfido.dart';

/// Traces Onfido calls with OpenTelemetry.
///
/// `otel_onfido` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Onfido call in
/// [tracedOnfido]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'onfido-example');

  // Wraps an Onfido API call in a CLIENT span.
  final onfidoId = await tracedOnfido<String>(
    operation: 'applicants.create',
    region: 'us-east-1',
    invoke: () async {
      // Make the Onfido call here, then report what it returned.
      const id = 'onfido_8f3a2c';
      return const OnfidoCallResult(
          value: id,
          result: OnfidoResult(
              checkId: 'check_8f3a2c',
              applicantId: 'applicant_id',
              checkStatus: 'in_progress',
              checkResult: 'clear',
              reportNames: 'example',
              subResult: 'clear',
              documentType: 'passport',
              workflowRunId: 'workflowrun_8f3a2c',
              region: 'eu',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedOnfido applicants.create returned $onfidoId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutOnfidoInstrumentationAsync.
  await runWithoutOnfidoInstrumentationAsync(
    () => tracedOnfido<String>(
      operation: 'applicants.create',
      region: 'us-east-1',
      invoke: () async {
        const id = 'onfido_8f3a2c';
        return const OnfidoCallResult(
            value: id,
            result: OnfidoResult(
                checkId: 'check_8f3a2c',
                applicantId: 'applicant_id',
                checkStatus: 'in_progress',
                checkResult: 'clear',
                reportNames: 'example',
                subResult: 'clear',
                documentType: 'passport',
                workflowRunId: 'workflowrun_8f3a2c',
                region: 'eu',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
