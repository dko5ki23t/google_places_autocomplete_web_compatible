import 'package:dio/dio.dart';
import 'package:dio_web_adapter/dio_web_adapter.dart';
import 'package:flutter/foundation.dart';

class DioAPIServices {
  static DioAPIServices get instance => _instance;
  static final DioAPIServices _instance = DioAPIServices._();
  DioAPIServices._();
  final DioForBrowser _dio = DioForBrowser();

  Dio _launchDio() {
    _dio.interceptors.add(
      LogInterceptor(
        request: false,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        logPrint: (object) {},
        error: true,
      ),
    );
    _dio.httpClientAdapter = BrowserHttpClientAdapter();
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 20);
    _dio.options.sendTimeout = const Duration(seconds: 30);
    _dio.options.followRedirects = false;
    _dio.options.validateStatus = (s) {
      if (s != null) {
        return s < 500;
      } else {
        return false;
      }
    };
    return _dio;
  }

  Future<Response?> post(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    final dio = _launchDio();

    try {
      final response = await dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        onSendProgress: onSendProgress,
      );
      return response;
    } on DioException catch (e) {
      debugPrint('Dio Error');
      debugPrint(e.message.toString());
      return null;
    } catch (e) {
      debugPrint('Unknown Error');
      debugPrint(e.toString());
      return null;
    }
  }

  Future<Response?> get(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) async {
    final dio = _launchDio();
    try {
      final response = await dio.get(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      debugPrint('Dio Error');
      debugPrint(e.message.toString());
      return null;
    } catch (e) {
      debugPrint('Unknown Error');
      debugPrint(e.toString());
      return null;
    }
  }
}
