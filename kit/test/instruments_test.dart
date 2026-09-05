// The instruments: the context from `usage`, the pool from
// `rate_limit_event`, and `/compact` in `-p` — on lines captured from
// Claude Code 2.1.261 on 2026-09-06 (the spike in app/DESIGN.md).
import 'package:flutter_kit/kit.dart';
import 'package:test/test.dart';

const _assistant =
    '{"type":"assistant","message":{"model":"claude-fable-5-1","id":"msg_1","role":"assistant","content":[{"type":"text","text":"Counted."}],"stop_reason":null,"usage":{"input_tokens":32,"cache_creation_input_tokens":3892,"cache_read_input_tokens":20504,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":3892},"output_tokens":2,"service_tier":"standard"}},"session_id":"s1"}';
const _result =
    '{"type":"result","subtype":"success","is_error":false,"duration_ms":50006,"num_turns":9,"result":"Counted.","session_id":"s1","stop_reason":"end_turn","total_cost_usd":1.61,"usage":{"input_tokens":130,"cache_creation_input_tokens":68977,"cache_read_input_tokens":173377,"output_tokens":3747},"modelUsage":{"claude-haiku-4-5-20251001":{"inputTokens":934,"outputTokens":21,"contextWindow":200000,"costUSD":0.001},"claude-fable-5-1":{"inputTokens":130,"outputTokens":3747,"contextWindow":1000000,"costUSD":1.61}}}';
const _rate =
    '{"type":"rate_limit_event","rate_limit_info":{"status":"allowed","resetsAt":1788658200,"rateLimitType":"five_hour","overageStatus":"rejected","overageDisabledReason":"org_level_disabled","isUsingOverage":false,"unifiedWindows":{"five_hour":{"utilization":0.19,"resetsAt":1788658200},"seven_day":{"utilization":0.04,"resetsAt":1789066800},"seven_day_overage_included":{"utilization":0.08,"resetsAt":1789066800}}},"uuid":"u1","session_id":"s1"}';
const _compacting = '{"type":"system","subtype":"status","status":"compacting","session_id":"s1","uuid":"u2"}';
const _compacted = '{"type":"system","subtype":"status","status":null,"compact_result":"success","session_id":"s1","uuid":"u3"}';
const _boundary =
    '{"type":"system","subtype":"compact_boundary","session_id":"s1","uuid":"u4","compact_metadata":{"trigger":"manual","pre_tokens":80559,"post_tokens":3596,"cumulative_dropped_tokens":76963,"duration_ms":37920},"logical_parent_uuid":"p"}';
const _compactResult = '{"type":"result","subtype":"success","is_error":false,"duration_ms":0,"num_turns":0,"session_id":"s1","stop_reason":null,"usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}';
const _init = '{"type":"system","subtype":"init","session_id":"s1","model":"claude-fable-5-1","permissionMode":"default","tools":["Bash"]}';

void main() {
  test('usage on an assistant message is the context the call read', () {
    final e = parseBridgeLine(_assistant) as AssistantEvent;
    expect(e.usage, isNotNull);
    expect(e.usage!.context, 32 + 3892 + 20504);
    expect(e.usage!.output, 2);
  });

  test('the result carries the turn totals and each model\'s window', () {
    final e = parseBridgeLine(_result) as ResultEvent;
    expect(e.usage!.output, 3747);
    expect(e.contextWindows, {'claude-haiku-4-5-20251001': 200000, 'claude-fable-5-1': 1000000});
  });

  test('the rate limit event carries both windows', () {
    final e = parseBridgeLine(_rate) as RateLimitEvent;
    expect(e.fiveHour!.utilization, 0.19);
    expect(e.fiveHour!.resetsAt, DateTime.utc(2026, 9, 6, 1, 30));
    expect(e.sevenDay!.utilization, 0.04);
    expect(e.exhausted, isFalse);
    final rejected = parseBridgeLine(_rate.replaceFirst('"status":"allowed"', '"status":"rejected"')) as RateLimitEvent;
    expect(rejected.exhausted, isTrue);
    // Over the relay and back.
    final back = RateLimitEvent.fromMap(e.toMap());
    expect(back.fiveHour!.utilization, 0.19);
    expect(back.fiveHour!.resetsAt, e.fiveHour!.resetsAt);
    expect(back.sevenDay!.resetsAt, e.sevenDay!.resetsAt);
    expect(back.status, 'allowed');
  });

  test('the compaction lines parse', () {
    expect(parseBridgeLine(_compacting), isA<StatusEvent>().having((e) => e.status, 'status', 'compacting'));
    expect(parseBridgeLine(_compacted), isA<StatusEvent>().having((e) => e.compactResult, 'result', 'success'));
    final b = parseBridgeLine(_boundary) as CompactEvent;
    expect(b.trigger, 'manual');
    expect(b.preTokens, 80559);
    expect(b.postTokens, 3596);
  });

  test('the window: the result\'s word over the model name', () {
    expect(contextWindowFor('claude-opus-5'), 200000);
    expect(contextWindowFor('claude-opus-5[1m]'), 1000000);
    expect(contextWindowFor('claude-fable-5-1'), 1000000);
    expect(contextWindowFor(null), 200000);
    final t = Transcript()..apply(parseBridgeLine(_init)!);
    expect(t.contextWindow, 1000000);
    t.apply(parseBridgeLine(_result.replaceAll('1000000', '500000'))!);
    expect(t.contextWindow, 500000);
  });

  test('the transcript keeps the context, costs the turn, and drops on compaction', () {
    final t = Transcript()
      ..now = (() => DateTime.utc(2026, 9, 6, 1))
      ..apply(parseBridgeLine(_init)!)
      ..addUser('count the classes');
    expect(t.contextUsed, 0);
    t.apply(parseBridgeLine(_assistant)!);
    expect(t.contextUsed, 24428);
    expect(t.contextFraction, closeTo(0.0244, 0.001));
    expect(t.contextRelay, {'used': 24428, 'window': 1000000, 'at': '2026-09-06T01:00:00.000Z'});
    t.apply(parseBridgeLine(_result)!);
    final row = t.messages.last;
    expect(row.role, DeckRole.assistant);
    expect(row.turn!.context, 24428);
    expect(row.turn!.output, 3747);
    expect(DeckMessage.fromMap(row.toMap()).turn!.output, 3747);

    t.addUser('/compact');
    t.apply(parseBridgeLine(_compacting)!);
    expect(t.compacting, isTrue);
    t.apply(parseBridgeLine(_compacted)!);
    expect(t.compacting, isFalse);
    t.apply(parseBridgeLine(_init)!);
    t.apply(parseBridgeLine(_boundary)!);
    expect(t.messages.last.role, DeckRole.note);
    expect(t.messages.last.text, 'Compacted · 80.6K → 3.6K tokens.');
    expect(t.contextUsed, 3596);
    t.apply(parseBridgeLine(_compactResult)!);
    expect(t.turnOpen, isFalse);
    // No assistant row this turn: nothing to cost.
    expect(t.messages.where((m) => m.turn != null).length, 1);
    // A failed compaction says so.
    t.apply(parseBridgeLine(_compacted.replaceFirst('success', 'error'))!);
    expect(t.messages.last.text, 'Compaction failed (error).');
  });

  test('the readouts', () {
    expect(tokensLabel(850), '850');
    expect(tokensLabel(24428), '24.4K');
    expect(tokensLabel(173377), '173K');
    expect(tokensLabel(1000000), '1.0M');
    expect(thousands(1000000), '1,000,000');
    expect(thousands(999), '999');
    expect(thousands(24428), '24,428');
    final now = DateTime.utc(2026, 9, 6, 1);
    expect(untilLabel(now.add(const Duration(minutes: 72)), now: now), '1 h 12 m');
    expect(untilLabel(now.add(const Duration(minutes: 12)), now: now), '12 m');
    expect(untilLabel(now.add(const Duration(seconds: 20)), now: now), 'now');
    expect(untilLabel(now.add(const Duration(days: 3, hours: 2)), now: now), '3 d 2 h');
  });
}
