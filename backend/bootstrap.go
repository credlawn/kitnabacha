package main

import (
	"github.com/pocketbase/pocketbase/core"
)

func ptr(s string) *string { return &s }

func bootstrapCollections(app core.App) error {
	usersCol, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		return err
	}

	collections := []struct {
		name     string
		build    func() *core.Collection
		requires []string
	}{
		{
			name: "contacts",
			build: func() *core.Collection {
				c := core.NewBaseCollection("contacts")
				c.ListRule = ptr("user_id = @request.auth.id")
				c.ViewRule = ptr("user_id = @request.auth.id")
				c.CreateRule = ptr("user_id = @request.auth.id")
				c.UpdateRule = ptr("user_id = @request.auth.id")
				c.DeleteRule = ptr("user_id = @request.auth.id")
				c.Fields.Add(&core.TextField{Name: "name", Required: true, Max: 255})
				c.Fields.Add(&core.TextField{Name: "phone"})
				c.Fields.Add(&core.DateField{Name: "created_at"})
				c.Fields.Add(&core.DateField{Name: "updated_at"})
				c.Fields.Add(&core.BoolField{Name: "is_deleted"})
				c.Fields.Add(&core.RelationField{
					Name: "user_id", CollectionId: usersCol.Id, CascadeDelete: true, MaxSelect: 1,
				})
				return c
			},
		},
		{
			name: "expense_categories",
			build: func() *core.Collection {
				c := core.NewBaseCollection("expense_categories")
				c.ListRule = ptr("user_id = @request.auth.id")
				c.ViewRule = ptr("user_id = @request.auth.id")
				c.CreateRule = ptr("user_id = @request.auth.id")
				c.UpdateRule = ptr("user_id = @request.auth.id")
				c.DeleteRule = ptr("user_id = @request.auth.id")
				c.Fields.Add(&core.TextField{Name: "name", Required: true, Max: 255})
				c.Fields.Add(&core.TextField{Name: "icon"})
				c.Fields.Add(&core.TextField{Name: "color"})
				c.Fields.Add(&core.JSONField{Name: "sub_categories"})
				c.Fields.Add(&core.DateField{Name: "created_at"})
				c.Fields.Add(&core.DateField{Name: "updated_at"})
				c.Fields.Add(&core.BoolField{Name: "is_deleted"})
				c.Fields.Add(&core.RelationField{
					Name: "user_id", CollectionId: usersCol.Id, CascadeDelete: true, MaxSelect: 1,
				})
				return c
			},
		},
		{
			name: "transactions",
			requires: []string{"contacts"},
			build: func() *core.Collection {
				c := core.NewBaseCollection("transactions")
				c.ListRule = ptr("user_id = @request.auth.id")
				c.ViewRule = ptr("user_id = @request.auth.id")
				c.CreateRule = ptr("user_id = @request.auth.id")
				c.UpdateRule = ptr("user_id = @request.auth.id")
				c.DeleteRule = ptr("user_id = @request.auth.id")
				c.Fields.Add(&core.NumberField{Name: "amount"})
				c.Fields.Add(&core.SelectField{
					Name: "type", Values: []string{"give", "take", "receive", "pay"}, Required: true,
				})
				c.Fields.Add(&core.TextField{Name: "description"})
				c.Fields.Add(&core.DateField{Name: "date", Required: true})
				c.Fields.Add(&core.DateField{Name: "created_at"})
				c.Fields.Add(&core.DateField{Name: "updated_at"})
				c.Fields.Add(&core.BoolField{Name: "is_deleted"})
				c.Fields.Add(&core.RelationField{
					Name: "user_id", CollectionId: usersCol.Id, CascadeDelete: true, MaxSelect: 1,
				})
				return c
			},
		},
		{
			name: "expenses",
			requires: []string{"expense_categories"},
			build: func() *core.Collection {
				c := core.NewBaseCollection("expenses")
				c.ListRule = ptr("user_id = @request.auth.id")
				c.ViewRule = ptr("user_id = @request.auth.id")
				c.CreateRule = ptr("user_id = @request.auth.id")
				c.UpdateRule = ptr("user_id = @request.auth.id")
				c.DeleteRule = ptr("user_id = @request.auth.id")
				c.Fields.Add(&core.TextField{Name: "sub_category"})
				c.Fields.Add(&core.NumberField{Name: "amount"})
				c.Fields.Add(&core.TextField{Name: "remarks"})
				c.Fields.Add(&core.DateField{Name: "date", Required: true})
				c.Fields.Add(&core.DateField{Name: "created_at"})
				c.Fields.Add(&core.DateField{Name: "updated_at"})
				c.Fields.Add(&core.BoolField{Name: "is_deleted"})
				c.Fields.Add(&core.RelationField{
					Name: "user_id", CollectionId: usersCol.Id, CascadeDelete: true, MaxSelect: 1,
				})
				return c
			},
		},
	}

	for _, col := range collections {
		existing, _ := app.FindCollectionByNameOrId(col.name)
		if existing != nil {
			continue
		}

		c := col.build()

		// Increase id field max to support UUID-length IDs from existing data
		for i, f := range c.Fields {
			if tf, ok := f.(*core.TextField); ok && tf.Name == "id" {
				tf.Max = 64
				tf.Min = 1
				tf.Pattern = "^[a-z0-9-]+$"
				c.Fields[i] = tf
				break
			}
		}

		for _, relName := range col.requires {
			relCol, err := app.FindCollectionByNameOrId(relName)
			if err != nil {
				return err
			}

			if col.name == "transactions" {
				c.Fields.Add(&core.RelationField{
					Name: "contact_id", CollectionId: relCol.Id, Required: true, CascadeDelete: true, MaxSelect: 1,
				})
			}
			if col.name == "expenses" {
				c.Fields.Add(&core.RelationField{
					Name: "category_id", CollectionId: relCol.Id, Required: true, CascadeDelete: true, MaxSelect: 1,
				})
			}
		}

		if err := app.Save(c); err != nil {
			return err
		}
	}

	return nil
}
