import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Signs in to the Combitone account server and returns the personal
/// Clash subscription URL, or `null` when the dialog is dismissed.
class CombitoneLoginDialog extends StatefulWidget {
  const CombitoneLoginDialog({super.key});

  @override
  State<CombitoneLoginDialog> createState() => _CombitoneLoginDialogState();
}

class _CombitoneLoginDialogState extends State<CombitoneLoginDialog> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введите телефон и пароль');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final url = await fetchCombitoneSubscriptionUrl(phone, password);
      if (mounted) Navigator.of(context).pop<String>(url);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.response?.statusCode == 401
            ? 'Неверный телефон или пароль'
            : 'Сервер недоступен, попробуйте позже';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: 'Вход в Combitone',
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _submit,
          child: const Text('Войти'),
        ),
      ],
      child: Wrap(
        runSpacing: 16,
        children: [
          TextField(
            controller: _phoneController,
            enabled: !_isLoading,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Телефон или логин',
              hintText: '+7XXXXXXXXXX',
            ),
          ),
          TextField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: 'Пароль', errorText: _error),
          ),
          if (_isLoading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

/// Exchanges credentials for a JWT and builds the subscription URL that the
/// regular URL-profile updater can refresh without custom headers.
Future<String> fetchCombitoneSubscriptionUrl(
  String phone,
  String password,
) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final response = await dio.post<Map<String, dynamic>>(
    '$combitoneApiBase/api/auth/login',
    data: {'phone': phone, 'password': password},
  );
  final token = response.data?['token'] as String?;
  if (token == null || token.isEmpty) {
    throw DioException.badResponse(
      statusCode: 401,
      requestOptions: response.requestOptions,
      response: response,
    );
  }
  return Uri.parse(
    '$combitoneApiBase$combitoneSubscriptionPath',
  ).replace(queryParameters: {'token': token}).toString();
}
