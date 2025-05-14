import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_places_autocomplete/src/dio_api_services.dart';
import 'package:rxdart/rxdart.dart';

import 'model/place_details.dart';
import 'model/prediction.dart';

/// A service class to interact with the Google Places API.
///
/// Provides functionality to fetch autocomplete predictions and detailed
/// place information based on user queries and place IDs.
class GooglePlacesAutocomplete {
  /// Callback listner for delivering autocomplete predictions to the UI.
  final ListnerAutoCompletePredictions predictionsListner;

  /// Callback listner for delivering loading status.
  final ListnerLoadingPredictions? loadingListner;

  /// The Google Places API key required to make requests.
  final String apiKey;

  /// The time delay (in milliseconds) to debounce user input for predictions.
  ///
  /// This ensures that predictions are fetched after the user stops typing.
  /// Must be greater than or equal to 200ms to avoid performance issues.
  final int debounceTime;

  /// A list of country codes to filter predictions.
  ///
  /// For example: `['fr', 'us', 'de']` to restrict results to France, the US, and Germany.
  final List<String>? countries;

  /// A list of primary types to filter predictions.
  ///
  /// See the full list of supported types at:
  /// https://developers.google.com/maps/documentation/places/web-service/place-types#table-b
  final List<String>? primaryTypes;

  /// The language code for predictions, e.g., `en`, `fr`, `es`.
  final String? language;

  /// Indicates whether the service has been initialized.
  ///
  /// Ensures that API calls are only made after initialization.
  bool _isInitialized = false;

  /// Internal HTTP client for making API requests.
  late final DioAPIServices _dio;

  /// A stream controller for debouncing user input.
  final _subject = PublishSubject<String>();

  /// Constructs a [GooglePlacesAutocomplete] instance.
  ///
  /// - [predictionsListner]: Callback for receiving predictions.
  /// - [loadingListner]: Callback for receiving prediction loading state.
  /// - [apiKey]: The Google Places API key.
  /// - [debounceTime]: The time delay for debouncing input (minimum 200ms).
  /// - [countries]: List of country codes for filtering predictions.
  /// - [primaryTypes]: List of primary types for filtering predictions.
  /// - [language]: Language code for predictions.
  GooglePlacesAutocomplete({
    required this.predictionsListner,
    required this.apiKey,
    this.loadingListner,
    this.debounceTime = 300,
    this.countries,
    this.primaryTypes,
    this.language,
  }) : assert(debounceTime >= 200,
            "Debounce time must be at least 200ms to ensure performance.");

  /// Initializes the service and sets up the stream for debouncing user input.
  void initialize() {
    _isInitialized = true;
    _dio = DioAPIServices.instance;
    _subject.stream
        .distinct()
        .debounceTime(Duration(milliseconds: debounceTime))
        .listen(_fetchPredictions);
  }

  /// Fetches autocomplete predictions based on the user query.
  ///
  /// Adds the query to the debounced stream for processing.
  /// If the query is empty, no action is taken.
  ///
  /// - [query]: The user input for which predictions are fetched.
  void getPredictions(String query) {
    if (query.trim().isEmpty) return;
    _subject.add(query);
  }

  /// Internal method to fetch autocomplete predictions from the Google Places API.
  ///
  /// Processes the user input after the debounce delay and retrieves predictions.
  /// Parses and delivers the results through the [predictionsListner] callback.
  ///
  /// - [query]: The debounced user input.
  Future<void> _fetchPredictions(String query) async {
    if (!_isInitialized) {
      throw Exception("Google Places Service is not initialized.");
    }

    const String url = "https://places.googleapis.com/v1/places:autocomplete";

    try {
      // Loading starts
      loadingListner?.call(true);

      final response = await _dio.post(
        url,
        options: Options(headers: {
          "Content-Type": "application/json",
          "X-Goog-FieldMask":
              "suggestions.placePrediction.structuredFormat.mainText.text,"
                  "suggestions.placePrediction.structuredFormat.secondaryText.text,"
                  "suggestions.placePrediction.placeId",
          "X-Goog-Api-Key": apiKey,
        }),
        data: jsonEncode({
          "input": query,
          "includedRegionCodes": countries,
          "includedPrimaryTypes": primaryTypes,
          "languageCode": language,
        }),
      );

      final Map data = response?.data ?? {};
      if (data.containsKey("error")) {
        throw Exception(data["error"]);
      }

      final List suggestions = data['suggestions'] ?? [];
      final Set<Prediction> predictions = {};

      for (var element in suggestions) {
        final prediction = Prediction.fromMap(element['placePrediction'] ?? {});
        predictions.add(prediction);
      }

      // Loading ends
      loadingListner?.call(false);

      predictionsListner.call(predictions.toList());
    } catch (e) {
      // Loading ends
      loadingListner?.call(false);

      debugPrint("GooglePlacesAutocomplete Error: $e");
    }
  }

  /// Fetches detailed information for a specific place using its Place ID.
  ///
  /// Makes a GET request to the Google Places API to retrieve details
  /// like address, location, phone numbers, and more.
  ///
  /// - [placeId]: The unique identifier of the place.
  /// - Returns: A [PlaceDetails] object with detailed information, or `null` on error.
  Future<PlaceDetails?> getPredictionDetail(String placeId) async {
    if (!_isInitialized) {
      throw Exception("Google Places Service is not initialized.");
    }

    final String url = "https://places.googleapis.com/v1/places/$placeId";

    try {
      final response = await _dio.get(
        url,
        options: Options(headers: {
          "Content-Type": "application/json",
          "X-Goog-FieldMask":
              "displayName,formattedAddress,nationalPhoneNumber,"
                  "internationalPhoneNumber,addressComponents,location,"
                  "googleMapsUri,websiteUri",
          "X-Goog-Api-Key": apiKey,
        }),
      );

      final Map data = response?.data ?? {};
      if (data.containsKey("error")) {
        throw Exception(data["error"]);
      }

      return PlaceDetails.fromMap(data);
    } catch (e) {
      debugPrint("GooglePlacesAutocomplete Error: $e");
      return null;
    }
  }
}

/// A type definition for the autocomplete predictions callback.
///
/// This function is called whenever new predictions are fetched from the API.
typedef ListnerAutoCompletePredictions = void Function(
    List<Prediction> predictions);

/// A type definition for the loading of autocomplete predictions.
///
/// This function is called whenever [getPredictions] method calls with a bolean.
typedef ListnerLoadingPredictions = void Function(bool isPredictionLoading);
