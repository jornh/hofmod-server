package auth

import (
	"errors"

	"github.com/labstack/echo/v4"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"{{ .ModuleImport }}/dm"
	"{{ .ModuleImport }}/server/db"
)

func passwordMiddleware(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {

		// already auth'd?
		if c.Get("user") != nil {
			return next(c)
		}

		email, password, ok := c.Request().BasicAuth()
		if !ok {
			return next(c)
		}

		// lookup user
		var user *dm.User
		err := db.DB.Table("users").Where("email = ?", email).First(user).Error
		if err != nil {
			if !errors.Is(err, gorm.ErrRecordNotFound) {
				c.Logger().Error(err)
			}
			return next(c)
		}
		if user == nil {
			return next(c)
		}

		// check password value
		err = bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password))
		// some password error, don't actually return the error
		if err != nil {
			return next(c)
		}

		// user auth'd
		c.Set("user", user)

		return next(c)
	}
}

func passwordRoutes(G *echo.Group) {
	g := G.Group("/password")
	g.GET("/reset", passwordResetRequest)
	g.POST("/reset", passwordResetDoReset)
}

func passwordResetRequest(c echo.Context) (err error) {

	return nil
}

func passwordResetDoReset(c echo.Context) (err error) {

	return nil
}