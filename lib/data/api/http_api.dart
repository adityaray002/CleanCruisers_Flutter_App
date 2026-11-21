// The real ShineStaff client. Filled in at step 4 of the plan, once
// ShineStaff implements docs/API_CONTRACT.md. Until then every call fails
// loudly instead of pretending to work.

import 'api.dart';

class HttpApi implements CleanCruisersApi {
  final String baseUrl;
  HttpApi(this.baseUrl);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'HttpApi.${invocation.memberName} is not built yet: use --dart-define=FAKE_SERVER=true');
}
