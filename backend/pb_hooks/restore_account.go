package pb_hooks

import (
	"github.com/pocketbase/pocketbase/core"
)

func RegisterRestoreAccountRoute(e *core.ServeEvent) {
	e.Router.POST("/api/account/restore", func(req *core.RequestEvent) error {
		user := req.Auth
		if user == nil {
			return req.JSON(401, map[string]any{"message": "Unauthorized"})
		}

		lg := req.App.Logger()
		lg.Info("restore_account: restoring user", "user_id", user.Id, "email", maskEmail(user.Email()))

		user.Set("marked_for_deletion", false)

		if err := req.App.Save(user); err != nil {
			lg.Error("restore_account: failed to restore user", "error", err)
			return req.JSON(500, map[string]any{"message": "Failed to restore account"})
		}

		lg.Info("restore_account: user restored successfully", "user_id", user.Id)
		return req.JSON(200, map[string]any{"message": "Account restored successfully"})
	})
}
