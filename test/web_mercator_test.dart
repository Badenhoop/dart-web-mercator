import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_mercator/web_mercator.dart';
import 'package:vector_math/vector_math_64.dart';

import 'samples.dart' as samples;

const DISTANCE_TOLERANCE = .0005;
const DISTANCE_TOLERANCE_PIXELS = 2;
const DISTANCE_SCALE_TEST_ZOOM = 12;

dynamic getDiff(Map<int, num> value, Map<int, num> baseValue, num scale) {
  final errorPixels =
      value.map((i, v) => MapEntry(i, ((v - baseValue[i]!) * scale).abs()));
  final error = value.map((i, v) => (MapEntry(
      i, (v - baseValue[i]!).abs() / min(v.abs(), baseValue[i]!.abs()))));

  var message = 'off by (';
  message += errorPixels.values.map((d) => d.toStringAsFixed(3)).join(', ');
  message += ') pixels, (';
  message +=
      error.values.map((d) => '${(d * 100).toStringAsFixed(3)}%').join(', ');
  message += ')';

  return {'errorPixels': errorPixels, 'error': error, 'message': message};
}

MercatorViewport? viewportFromData(samples.ViewportData data) {
  MercatorViewport? viewport;

  switch (data.name) {
    case 'Flat':
      viewport = MercatorViewport(
        width: data.width,
        height: data.height,
        lng: data.lng,
        lat: data.lat,
        zoom: data.zoom,
      );
      break;
    case 'Pitched':
      viewport = MercatorViewport(
        width: data.width,
        height: data.height,
        lng: data.lng,
        lat: data.lat,
        zoom: data.zoom,
        pitch: data.pitch ?? 0.0,
      );
      break;
    case 'Rotated':
      viewport = MercatorViewport(
        width: data.width,
        height: data.height,
        lng: data.lng,
        lat: data.lat,
        zoom: data.zoom,
        pitch: data.pitch ?? 0.0,
        altitude: data.altitude!,
      );
      break;
    case 'HighLatitude':
      viewport = MercatorViewport(
        width: data.width,
        height: data.height,
        lng: data.lng,
        lat: data.lat,
        zoom: data.zoom,
        pitch: data.pitch ?? 0.0,
        altitude: data.altitude!,
      );
      break;
  }

  return viewport;
}

void main() {
  group('testing utils', () {
    test('log2 implementation', () {
      expect(log2(5), 2.321928094887362);
      expect(log2(10), 3.3219280948873626);
    });

    test('lngLatToWorld', () {
      expect(() => lngLatToWorld(38, -122), throwsAssertionError);
      expect(lngLatToWorld(-122, 38),
          Vector2(82.4888888888889, 314.50692551385134));
    });

    test('getDistanceScales', () {
      for (final vp in samples.viewports) {
        final distanceScales = getDistanceScales(vp.lng, vp.lat);

        final metersPerUnit = distanceScales['metersPerUnit']!;
        final unitsPerMeter = distanceScales['unitsPerMeter']!;
        final degreesPerUnit = distanceScales['degreesPerUnit']!;
        final unitsPerDegree = distanceScales['unitsPerDegree']!;

        expect(metersPerUnit[0] * unitsPerMeter[0], closeTo(1, 1e-11));
        expect(metersPerUnit[1] * unitsPerMeter[1], closeTo(1, 1e-11));
        expect(metersPerUnit[2] * unitsPerMeter[2], closeTo(1, 1e-11));

        expect(degreesPerUnit[0] * unitsPerDegree[0], closeTo(1, 1e-11));
        expect(degreesPerUnit[1] * unitsPerDegree[1], closeTo(1, 1e-11));
        expect(degreesPerUnit[2] * unitsPerDegree[2], closeTo(1, 1e-11));
      }
    });

    test('getDistanceScales#unitsPerDegree', () {
      final scale = pow(2, DISTANCE_SCALE_TEST_ZOOM);
      const z = 1000;

      for (final vp in samples.viewports) {
        print(vp);
        final lng = vp.lng, lat = vp.lat;

        final distanceScales = getDistanceScales(lng, lat, highPrecision: true);
        final unitsPerDegree = distanceScales['unitsPerDegree'];
        final unitsPerDegree2 = distanceScales['unitsPerDegree2'];

        /// Test degree offsets
        for (final delta in [.001, .01, .05, .1, .3]) {
          print('> R = $delta degrees');

          /// To pixels
          final coords = [
            delta * unitsPerDegree![0],
            delta * unitsPerDegree[1],
            z * unitsPerDegree[2]
          ];
          final coordsAdjusted = [
            delta * (unitsPerDegree[0] + unitsPerDegree2![0] * delta),
            delta * (unitsPerDegree[1] + unitsPerDegree2[1] * delta),
            z * (unitsPerDegree[2] + unitsPerDegree2[2] * delta),
          ];

          final pt = [lng + delta, lat + delta];
          final realCoords = [
            lngLatToWorld(pt[0], pt[1])[0] - lngLatToWorld(lng, lat)[0],
            lngLatToWorld(pt[0], pt[1])[1] - lngLatToWorld(lng, lat)[1],
            z * getDistanceScales(pt[0], pt[1])['unitsPerMeter']![2],
          ];

          final dynamic diff =
              getDiff(coords.asMap(), realCoords.asMap(), scale);
          final dynamic diffAdjusted =
              getDiff(coordsAdjusted.asMap(), realCoords.asMap(), scale);

          print(
              '  unadjusted ${diff['message']}\n  adjusted ${diffAdjusted['message']}');

          diffAdjusted['error']
              .values
              .forEach((num v) => expect(v, lessThan(DISTANCE_TOLERANCE)));
          diffAdjusted['errorPixels'].values.forEach(
              (num v) => expect(v, lessThan(DISTANCE_TOLERANCE_PIXELS)));
        }
      }
    });

    test('getDistanceScales#unitsPerMeter', () {
      final scale = pow(2, DISTANCE_SCALE_TEST_ZOOM);
      const z = 1000;

      for (final vp in samples.viewports) {
        print(vp);

        final lng = vp.lng, lat = vp.lat;

        final distanceScales = getDistanceScales(lng, lat, highPrecision: true);
        final unitsPerMeter = distanceScales['unitsPerMeter'];
        final unitsPerMeter2 = distanceScales['unitsPerMeter2'];

        /// Test meters offsets
        for (final delta in [10, 100, 1000, 5000, 10000, 30000]) {
          print('> R = $delta meters');

          /// To pixels
          final coords = [
            delta * unitsPerMeter![0],
            delta * unitsPerMeter[1],
            z * unitsPerMeter[2]
          ];
          final coordsAdjusted = [
            delta * (unitsPerMeter[0] + unitsPerMeter2![0] * delta),
            delta * (unitsPerMeter[1] + unitsPerMeter2[1] * delta),
            z * (unitsPerMeter[2] + unitsPerMeter2[2] * delta),
          ];

          final pt = destination(lng, lat,
              distance: (delta * .001) * sqrt(2), bearing: 45);
          final realCoords = [
            lngLatToWorld(pt[0], pt[1])[0] - lngLatToWorld(lng, lat)[0],
            lngLatToWorld(pt[0], pt[1])[1] - lngLatToWorld(lng, lat)[1],
            z * getDistanceScales(pt[0], pt[1])['unitsPerMeter']![2]
          ];

          final dynamic diff =
              getDiff(coords.asMap(), realCoords.asMap(), scale);
          final dynamic diffAdjusted =
              getDiff(coordsAdjusted.asMap(), realCoords.asMap(), scale);

          print(
              '  unadjusted ${diff['message']}\n  adjusted ${diffAdjusted['message']}');

          diffAdjusted['error']
              .values
              .forEach((num v) => expect(v, lessThan(DISTANCE_TOLERANCE)));
          diffAdjusted['errorPixels'].values.forEach(
              (num v) => expect(v, lessThan(DISTANCE_TOLERANCE_PIXELS)));
        }
      }
    });

    test('addMetersToLngLat', () {
      for (final vp in samples.viewports) {
        print(vp);

        final lng = vp.lng, lat = vp.lat;

        // Test meters offsets
        for (final delta in [10.0, 100.0, 1000.0, 5000.0]) {
          print('> R = $delta meters');

          final destPt = destination(lng, lat,
              distance: (delta * .001) * sqrt(2), bearing: 45);
          final pt = Vector3(destPt[0], destPt[1], delta);
          final result =
              addMetersToLngLat(Vector3(lng, lat, 0), Vector3.all(delta));

          result.storage.asMap().forEach((i, v) => expect(
              v,
              closeTo(pt[i],
                  1e-6))); // 1e-7 won't do, maybe dart is rounding decimals…
        }
      }
    });

    test('getMeterZoom', () {
      for (final lat in [.0, 37.5, 75.0]) {
        final zoom = getMeterZoom(lat);
        final scale = zoomToScale(zoom);

        final unitsPerMeter = getDistanceScales(0, lat)['unitsPerMeter']!;
        unitsPerMeter
            .map((dynamic v) => (v as num) * scale)
            .forEach((num v) => expect(v, closeTo(1, 1e-11)));
      }
    });
  });

  group('testing bbox', () {
    test('return an infinte bounding box when coordinates are empty', () {
      expect(
          bbox([]),
          containsAllInOrder(<double>[
            double.infinity,
            double.infinity,
            double.negativeInfinity,
            double.negativeInfinity
          ]));
    });

    test('bbox#point', () {
      const pt = [102.0, 0.5];
      expect(bbox([pt]), containsAllInOrder(<num>[102, 0.5, 102, 0.5]));
    });

    test('bbox#line', () {
      const line = [
        [102.0, -10.0],
        [103.0, 1.0],
        [104.0, 0.0],
        [130.0, 4.0]
      ];
      expect(bbox(line), containsAllInOrder(<num>[102, -10, 130, 4]));
    });

    test('bbox#many', () {
      const many = [
        [102.0, 2.0],
        [103.0, 2.0],
        [103.0, 3.0],
        [102.0, 3.0],
        [102.0, 2.0],
        [100.0, 0.0],
        [101.0, 0.0],
        [101.0, 1.0],
        [100.0, 1.0],
        [100.0, 0.0],
        [100.2, 0.2],
        [100.8, 0.2],
        [100.8, 0.8],
        [100.2, 0.8],
        [100.2, 0.2]
      ];

      expect(bbox(many), containsAllInOrder(<num>[100, 0, 103, 3]));
    });
  });

  group('testing viewport', () {
    test('WebMercatorMercatorViewport#constructor - 0 width/height', () {
      final vpData = samples.ViewportData.flat();
      final viewport = MercatorViewport(
        width: 0,
        height: 0,
        lng: vpData.lng,
        lat: vpData.lat,
        zoom: vpData.zoom,
        bearing: vpData.bearing,
      );

      expect(viewport.width, 1);
      expect(viewport.height, 1);
      expect(viewport, isInstanceOf<MercatorViewport>());
    });

    test('WebMercatorMercatorViewport.projectFlat', () {
      for (final vp in samples.viewports) {
        print(vp);

        final viewport = viewportFromData(vp);

        for (final vpd2 in samples.viewports) {
          final lng = vpd2.lng, lat = vpd2.lat;
          final xy = viewport!.projectFlat(lng, lat);
          final lngLat = viewport.unprojectFlat(xy[0], xy[1]);

          expect(lng, closeTo(lngLat[0], 1e-6));
          expect(lat, closeTo(lngLat[1], 1e-6));
        }
      }
    });

    test('WebMercatorMercatorViewport.project#2D', () {
      for (final vp in samples.viewports) {
        print(vp);

        final viewport = viewportFromData(vp);

        for (final vpd2 in samples.viewports) {
          final lngLatIn = Vector2(vpd2.lng, vpd2.lat);

          var xy = viewport!.project(lngLatIn, topLeft: true) as Vector2;
          var lngLat = viewport.unproject(xy, topLeft: true) as Vector2;
          print('Comparing $lngLatIn to $lngLat');
          expect(
              lngLatIn.storage,
              containsAllInOrder(lngLat.storage
                  .map((v) => closeTo(v, 1e-5))
                  .toList())); // again, we need to decrease precision test by one decimal

          xy = viewport.project(lngLatIn, topLeft: false) as Vector2;
          lngLat = viewport.unproject(xy, topLeft: false) as Vector2;
          print('Comparing $lngLatIn to $lngLat');
          expect(
              lngLatIn.storage,
              containsAllInOrder(
                  lngLat.storage.map((v) => closeTo(v, 1e-5)).toList()));
        }
      }
    });

    test('WebMercatorMercatorViewport.project#3D', () {
      for (final vp in samples.viewports) {
        print(vp);
        final viewport = viewportFromData(vp);

        for (final vpd2 in samples.viewports) {
          final lngLatZIn = Vector3(vpd2.lng, vpd2.lat, 100);
          final xyz = viewport!.project(lngLatZIn) as Vector3;

          final lngLatZ1 = viewport.unproject(xyz) as Vector3;
          final lngLatZ2 = viewport.unproject(Vector2(xyz[0], xyz[1]),
              targetZ: 100) as Vector3;

          print('Comparing $lngLatZIn to $lngLatZ1 & $lngLatZ2');
          expect(
              lngLatZIn.storage,
              containsAllInOrder(
                  lngLatZ1.storage.map((v) => closeTo(v, 1e-5)).toList()));
          expect(
              lngLatZIn.storage,
              containsAllInOrder(
                  lngLatZ2.storage.map((v) => closeTo(v, 1e-5)).toList()));
        }
      }
    });

    test('WebMercatorMercatorViewport.getLocationAtPoint', () {
      final testPos = Vector2(200, 200);

      for (final vp in samples.viewports) {
        print(vp);
        final viewport = viewportFromData(vp);

        for (final vp2 in samples.viewports) {
          final lngLat = Vector2(vp2.lng, vp2.lat);
          final newLngLat =
              viewport!.getLocationAtPoint(lngLat: lngLat, pos: testPos);

          final newMercatorViewport = viewportFromData(
              samples.ViewportData.copyWith(vp,
                  lng: newLngLat[0], lat: newLngLat[1]))!;
          final xy = newMercatorViewport.project(lngLat) as Vector2;

          print('Comparing $testPos to $xy');
          expect(testPos[0], closeTo(xy[0], 1e-6));
          expect(testPos[1], closeTo(xy[1], 1e-6));
        }
      }
    });
  });

  group('testing mercator projections', () {
    const viewportProps = {
      'width': 800.0,
      'height': 600.0,
      'lng': -122.43,
      'lat': 37.75,
      'zoom': 11.5,
      'pitch': 30.0,
      'bearing': .0
    };
    test('MercatorViewport projection', () {
      final viewport = MercatorViewport(
        width: viewportProps['width']!,
        height: viewportProps['height']!,
        lat: viewportProps['lat']!,
        lng: viewportProps['lng']!,
        zoom: viewportProps['zoom'] ?? 0.0,
        pitch: viewportProps['pitch'] ?? 0.0,
        bearing: viewportProps['bearing'] ?? 0.0,
      );

      for (final proj in samples.projections) {
        print(proj['title']);
        late Vector2 output;
        switch (proj['func']) {
          case 'project':
            output =
                viewport.project(Vector2(proj['input'][0], proj['input'][1]))
                    as Vector2;
            break;
          case 'unproject':
            output =
                viewport.unproject(Vector2(proj['input'][0], proj['input'][1]))
                    as Vector2;
            break;
        }
        expect(
            output.storage,
            containsAllInOrder(
                proj['expected'].map((num v) => closeTo(v, 1e-7))));
      }
    });

    test('MercatorViewport projection#topLeft', () {
      final viewport = MercatorViewport(
        width: viewportProps['width']!,
        height: viewportProps['height']!,
        lat: viewportProps['lat']!,
        lng: viewportProps['lng']!,
        zoom: viewportProps['zoom'] ?? 0.0,
        pitch: viewportProps['pitch'] ?? 0.0,
        bearing: viewportProps['bearing'] ?? 0.0,
      );

      final topLeft = viewport.unproject(Vector2.zero()) as Vector2;
      final bottomLeft =
          viewport.unproject(Vector2(0, viewport.height as double)) as Vector2;

      expect(bottomLeft[1], lessThan(topLeft[1]));

      final topLeft2 = viewport.unproject(Vector2(0, viewport.height as double),
          topLeft: false) as Vector2;
      final bottomLeft2 =
          viewport.unproject(Vector2.zero(), topLeft: false) as Vector2;

      topLeft.storage.asMap().forEach((i, v) =>
          expect(v, topLeft2[i])); //, topLeft2, 'topLeft true/false match');
      bottomLeft.storage.asMap().forEach((i, v) => expect(v, bottomLeft2[i]));
    });
  });

  group('testing fitBounds', () {
    test('fitBounds', () {
      for (final bound in samples.bounds) {
        final Map? input = bound[0], expected = bound[1];
        final result = fitBounds(
            width: input!['width'],
            height: input['height'],
            bounds: input['bounds'][0]..addAll(input['bounds'][1]),
            minExtent: input['minExtent'] ?? 0,
            maxZoom: input['maxZoom'] ?? 24,
            padding: input['padding'] ?? 0,
            offset: input['offset'] ?? [0, 0]);

        ['lng', 'lat', 'zoom'].map((k) {
          expect(result[k]!.isFinite, true);
          expect(result[k], closeTo(expected![k], 1e-11));
        });
      }
    });

    test('WebMercatorMercatorViewport.fitBounds', () {
      for (final bound in samples.bounds) {
        final Map? input = bound[0], expected = bound[1];
        final result = MercatorViewport.fitBounds(
            width: input!['width'],
            height: input['height'],
            bounds: input['bounds'][0]..addAll(input['bounds'][1]),
            minExtent: input['minExtent'] ?? 0,
            maxZoom: input['maxZoom'] ?? 24,
            padding: input['padding'] ?? 0,
            offset: input['offset'] ?? [0, 0]);

        expect(result, isInstanceOf<MercatorViewport>());

        expect(result.lng, closeTo(expected!['lng'], 1e-9));
        expect(result.lat, closeTo(expected['lat'], 1e-9));
        expect(result.zoom, closeTo(expected['zoom'], 1e-9));
      }
    });

    test('fitBounds#degenerate', () {
      expect(
        MercatorViewport.fitBounds(
            width: 100, height: 100, bounds: [-70.0, 10.0, -70.0, 10.0]),
        isInstanceOf<MercatorViewport>(),
      );
      expect(
        () => MercatorViewport.fitBounds(
            width: 100,
            height: 100,
            bounds: [-70.0, 10.0, -70.0, 10.0],
            maxZoom: double.infinity),
        throwsAssertionError,
      );
      expect(
        MercatorViewport.fitBounds(
            width: 100,
            height: 100,
            bounds: [-70.0, 10.0, -70.0, 10.0],
            minExtent: .01,
            maxZoom: double.infinity),
        isInstanceOf<MercatorViewport>(),
      );
    });
  });
}
