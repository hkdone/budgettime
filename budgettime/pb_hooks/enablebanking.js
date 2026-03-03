// Router PocketBase pour interagir facilement avec Enable Banking
// Nous testons la connexion avec notre module natif Go (Bridge JWT)

routerAdd("GET", "/api/test-banking", (c) => {
    // 1. Appeler notre propre API interne PocketBase Go (pour récupérer le JWT fraîchement signé)
    // C'est la route `e.Router.GET("/api/banking/jwt")` que nous avons codée dans main.go
    const resJWT = $http.send({
        url: "http://127.0.0.1:8090/api/banking/jwt",
        method: "GET",
    });

    if (resJWT.statusCode !== 200) {
        throw new BadRequestError("Failed to fetch internal Token: " + resJWT.raw);
    }

    // Extraction du Jeton Signature
    const internalAuth = resJWT.json;
    const jwtToken = internalAuth.token;

    // 2. Tester l'Authentification auprès du vrai serveur Enable Banking (Environnement de Test/Sandbox)
    // Appel d'API pour vérifier l'exactitude de la signature.
    // POST /application
    const bankRes = $http.send({
        url: "https://api.enablebanking.com/application",
        method: "GET",
        headers: {
            "Authorization": "Bearer " + jwtToken,
            "Content-Type": "application/json"
        }
    });

    // 3. Renvoyer le Résultat au Navigateur de l'utilisateur
    return c.json(200, {
        "status": "Test terminé",
        "jwt_generated": jwtToken.substring(0, 15) + "...",
        "api_response_code": bankRes.statusCode,
        "api_response_body": bankRes.json || bankRes.raw
    });
});
