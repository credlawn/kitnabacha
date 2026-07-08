package pb_hooks

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/forms"
)

func safePrefix(s string) string {
	if len(s) > 20 {
		return s[:20] + "..."
	}
	return s
}

func maskEmail(email string) string {
	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return "***"
	}
	if len(parts[0]) <= 2 {
		return parts[0][:1] + "***@" + parts[1]
	}
	return parts[0][:2] + "***@" + parts[1]
}

func RegisterGoogleAuthRoute(e *core.ServeEvent) {
	e.Router.POST("/api/auth/google", func(req *core.RequestEvent) error {
		lg := req.App.Logger()

		body, err := io.ReadAll(req.Request.Body)
		if err != nil {
			lg.Error("google_auth: failed to read body", "error", err)
			return req.JSON(400, map[string]any{"message": "Invalid request body"})
		}

		var data struct {
			IdToken string `json:"idToken"`
		}
		if err := json.Unmarshal(body, &data); err != nil || data.IdToken == "" {
			lg.Warn("google_auth: missing idToken in request body")
			return req.JSON(400, map[string]any{"message": "idToken is required"})
		}

		lg.Info("google_auth: verifying token with Google", "token_prefix", safePrefix(data.IdToken))

		resp, err := http.Get("https://oauth2.googleapis.com/tokeninfo?id_token=" + data.IdToken)
		if err != nil {
			lg.Error("google_auth: tokeninfo HTTP request failed", "error", err)
			return req.JSON(401, map[string]any{"message": "Failed to verify token with Google"})
		}
		defer resp.Body.Close()

		lg.Info("google_auth: tokeninfo response received", "status", resp.StatusCode)

		if resp.StatusCode != 200 {
			bodyBytes, _ := io.ReadAll(resp.Body)
			lg.Error("google_auth: Google rejected the token",
				"status", resp.StatusCode,
				"response", string(bodyBytes),
			)
			return req.JSON(401, map[string]any{"message": "Invalid ID token"})
		}

		var payload struct {
			Email         string `json:"email"`
			Name          string `json:"name"`
			EmailVerified string `json:"email_verified"`
			Sub           string `json:"sub"`
			Aud           string `json:"aud"`
			Azp           string `json:"azp"`
		}
		if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
			lg.Error("google_auth: failed to decode tokeninfo payload", "error", err)
			return req.JSON(500, map[string]any{"message": "Failed to parse Google response"})
		}

		lg.Info("google_auth: decoded token payload",
			"email", maskEmail(payload.Email),
			"name", payload.Name,
			"email_verified", payload.EmailVerified,
			"sub", safePrefix(payload.Sub),
			"aud", safePrefix(payload.Aud),
			"azp", safePrefix(payload.Azp),
		)

		if payload.Email == "" || payload.EmailVerified != "true" {
			lg.Warn("google_auth: email missing or unverified",
				"email", maskEmail(payload.Email),
				"verified", payload.EmailVerified,
			)
			return req.JSON(400, map[string]any{"message": "Email not available or not verified from Google"})
		}

		user, err := e.App.FindAuthRecordByEmail("users", payload.Email)
		if err != nil {
			lg.Info("google_auth: user not found, creating new account",
				"email", maskEmail(payload.Email),
			)

			collection, err := e.App.FindCollectionByNameOrId("users")
			if err != nil {
				lg.Error("google_auth: failed to find users collection", "error", err)
				return req.JSON(500, map[string]any{"message": "Server configuration error"})
			}

			user = core.NewRecord(collection)
			user.Set("email", payload.Email)
			user.Set("name", payload.Name)

			pass := "google" + strings.Split(payload.Email, "@")[0]

			form := forms.NewRecordUpsert(e.App, user)
			form.GrantSuperuserAccess()
			form.Load(map[string]any{
				"verified":        true,
				"password":        pass,
				"passwordConfirm": pass,
			})
			if err := form.Submit(); err != nil {
				lg.Error("google_auth: failed to create new user",
					"error", err,
					"email", maskEmail(payload.Email),
				)
				return req.JSON(500, map[string]any{"message": "Failed to create user: " + err.Error()})
			}

			lg.Info("google_auth: new user created successfully",
				"user_id", user.Id,
				"email", maskEmail(payload.Email),
			)
		} else {
			lg.Info("google_auth: existing user found",
				"user_id", user.Id,
				"email", maskEmail(payload.Email),
			)
		}

		token, err := user.NewAuthToken()
		if err != nil {
			lg.Error("google_auth: failed to generate auth token",
				"error", err,
				"user_id", user.Id,
			)
			return req.JSON(500, map[string]any{"message": "Failed to generate auth token"})
		}

		lg.Info("google_auth: login successful",
			"user_id", user.Id,
		)

		return req.JSON(200, map[string]any{
			"token":  token,
			"record": user.PublicExport(),
		})
	})
}
