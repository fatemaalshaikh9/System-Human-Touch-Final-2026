const functions = require("firebase-functions");
const axios = require("axios");
const admin = require("firebase-admin");

admin.initializeApp();

/* =========================
   📍 1. SEARCH ACCESSIBLE PLACES
========================= */
exports.searchAccessiblePlaces = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    const { query, userLat, userLng } = req.body;

    if (!query || userLat === undefined || userLng === undefined) {
      return res.status(400).json({
        error: "Missing required fields",
      });
    }

    const apiKey = "AIzaSyBwSBFpGS21Df4VjZg6VbqlBinKS0nFpaM";

    const placeType = getPlaceType(query);
    const keyword = getKeyword(query);

    let placesUrl =
      "https://maps.googleapis.com/maps/api/place/nearbysearch/json" +
      `?location=${userLat},${userLng}` +
      "&radius=10000" +
      `&keyword=${encodeURIComponent(keyword)}` +
      `&key=${apiKey}`;

    if (placeType) {
      placesUrl += `&type=${placeType}`;
    }

    const response = await axios.get(placesUrl);
    const data = response.data;

    if (data.status !== "OK" && data.status !== "ZERO_RESULTS") {
      return res.status(500).json({
        error: "Google Places API error",
        status: data.status,
        details: data.error_message || "",
      });
    }

    const results = data.results || [];

    const mappedResults = results.map((place) => {
      const lat = place.geometry.location.lat;
      const lng = place.geometry.location.lng;

      return {
        id: place.place_id,
        name: place.name,
        category: formatCategory(place.types?.[0] || "Place"),
        lat: lat,
        lng: lng,
        distanceKm: calculateDistance(
          Number(userLat),
          Number(userLng),
          lat,
          lng
        ),
        wheelchairEntrance: true,
        accessibleParking: true,
        accessibleRestroom: true,
        accessibleSeating: true,
        note: place.vicinity || "Nearby place from Google Maps",
        mapsUri: `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`,
      };
    });

    return res.status(200).json({
      results: mappedResults,
    });
  } catch (error) {
    return res.status(500).json({
      error: "Search failed",
      details: error.message,
    });
  }
});

/* =========================
   📞 2. CALL NOTIFICATION
========================= */
exports.sendCallNotification = functions.https.onCall(async (data, context) => {
  try {
    const { token, callerName, callerId, callType, volunteerId } = data;

    if (!token) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing FCM token"
      );
    }

    const message = {
      notification: {
        title: "📞 Incoming Call",
        body: `${callerName || "Someone"} is calling you`,
      },
      data: {
        type: "call",
        callerName: callerName || "",
        callerId: callerId || "",
        callType: callType || "video",
        volunteerId: volunteerId || "",
      },
      token: token,
    };

    const response = await admin.messaging().send(message);

    return {
      success: true,
      messageId: response,
    };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/* =========================
   🧠 HELPERS
========================= */
function getPlaceType(query) {
  const q = query.toLowerCase();

  if (q.includes("hospital") || q.includes("مستشفى")) return "hospital";
  if (q.includes("cafe") || q.includes("coffee") || q.includes("كوفي")) return "cafe";
  if (q.includes("restaurant") || q.includes("مطعم")) return "restaurant";
  if (q.includes("mall") || q.includes("مجمع")) return "shopping_mall";
  if (q.includes("park") || q.includes("حديقة")) return "park";

  return null;
}

function getKeyword(query) {
  return query;
}

function formatCategory(type) {
  return type
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371;

  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) ** 2;

  return Number(
    (2 * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))).toFixed(2)
  );
}

function toRad(value) {
  return (value * Math.PI) / 180;
}