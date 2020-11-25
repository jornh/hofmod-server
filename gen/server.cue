package gen

import (
	"list"
	"path"

  hof "github.com/hofstadter-io/hof/schema"

  "github.com/hofstadter-io/hofmod-server/schema"
)

#ServerGen: hof.#HofGenerator & {
	// User inputs
  Outdir: string | *"./"
	Module: string
  PackageName: "" | *"github.com/hofstadter-io/hofmod-server"

  Server: schema.#Server
	Datamodel: hof.#Datamodel & {
		Modelsets: {
			Custom: hof.#Modelset
			Builtin: hof.#Modelset
		}
	}

  // Internal
  In: {
    SERVER: Server
		MODELS: {
			Custom: Datamodel.Modelsets.Custom
			Builtin: Datamodel.Modelsets.Builtin
		}
		ModuleImport: path.Clean("\(Module)/\(Outdir)")
  }

  OutdirConfig: {
    CiOutdir: string | *"\(Outdir)/ci/\(In.SERVER.serverName)"
    ServerOutdir: string | *"\(Outdir)/server"
  }

  basedir: "server/\(In.SERVER.serverName)"

  PartialsDir:  "./partials/"
  TemplatesDir: "./templates/"

	// Actual files generated by hof, flattened into a single list
  Out: [...hof.#HofGeneratorFile] & list.FlattenN(_All , 1)

  // Combine everything together and output files that might need to be generated
  _All: [
   [ for _, F in _OnceFiles { F } ],

   [ for _, F in _BuiltinModelFiles { F } ],
   [ for _, F in _CustomModelFiles { F } ],

   [ for _, F in _L1_RouteFiles { F } ],
   [ for _, F in _L2_RouteFiles { F } ],
   [ for _, F in _L3_RouteFiles { F } ],

   [ for _, F in _L1_ResourceFiles { F } ],
  ]

  // Files that are not repeatedly used, they are generated once for the whole CLI
  _OnceFiles: [...hof.#HofGeneratorFile] & [
    {
			// 4-5X slowdown from this
			//TemplateConfig: {
				//TemplateSystem: "raymond"
			//}
      TemplateName: "config.go"
      Filepath: "\(Outdir)/config/config.go"
    },
		{
			TemplateName: "mailer/mailgun.go"
			Filepath: "\(Outdir)/mailer/mailgun.go"
		},
		{
			TemplateName: "mailer/emails.go"
			Filepath: "\(Outdir)/mailer/emails.go"
		},
		{
			TemplateName: "db/common.go"
			Filepath: "\(Outdir)/db/common.go"
		},
		{
			TemplateName: "db/migrate.go"
			Filepath: "\(Outdir)/db/migrate.go"
		},
		{
			TemplateName: "db/seed.go"
			Filepath: "\(Outdir)/db/seed.go"
		},
		{
			TemplateName: "db/postgres.go"
			Filepath: "\(Outdir)/db/postgres.go"
		},
		{
			TemplateName: "client/do.go"
			Filepath: "\(Outdir)/client/do.go"
		},
		{
			TemplateName: "client/client.go"
			Filepath: "\(Outdir)/client/client.go"
		},
    {
      TemplateName: "server.go"
      Filepath: "\(OutdirConfig.ServerOutdir)/server.go"
    },
    {
      TemplateName: "router.go"
      Filepath: "\(OutdirConfig.ServerOutdir)/router.go"
    },
    {
      TemplateName: "middleware.go"
      Filepath: "\(OutdirConfig.ServerOutdir)/middleware.go"
    },
		{
			TemplateName: "auth/middleware.go"
			Filepath: "\(OutdirConfig.ServerOutdir)/auth/middleware.go"
		},
		{
			TemplateName: "auth/routes.go"
			Filepath: "\(OutdirConfig.ServerOutdir)/auth/routes.go"
		},
		{
			TemplateName: "auth/pword.go"
			Filepath: "\(OutdirConfig.ServerOutdir)/auth/pword.go"
		},
		{
			TemplateName: "auth/apikey.go"
			Filepath: "\(OutdirConfig.ServerOutdir)/auth/apikey.go"
		},
		{
			TemplateName: "auth/accts.go"
			Filepath: "\(OutdirConfig.ServerOutdir)/auth/accts.go"
		},
		if Server.EntityConfig.users {
			{
				TemplateName: "auth/user.go"
				Filepath: "\(OutdirConfig.ServerOutdir)/auth/user.go"
			}
		}
		if Server.EntityConfig.groups {
			{
				TemplateName: "auth/group.go"
				Filepath: "\(OutdirConfig.ServerOutdir)/auth/group.go"
			}
		}
		if Server.EntityConfig.organizations {
			{
				TemplateName: "auth/organization.go"
				Filepath: "\(OutdirConfig.ServerOutdir)/auth/organization.go"
			}
		}
  ]

	// Models
  _BuiltinModelFiles: [...hof.#HofGeneratorFile] & [ // List comprehension
    for _, M in Datamodel.Modelsets.Builtin.MigrateOrder
    {
      In: {
				MODEL: {
					M
          PackageName: "dm"
				}
      }
      TemplateName: "dm/model.go"
      Filepath: "\(Outdir)/dm/\(M.modelName).go"
    }
  ]

  _CustomModelFiles: [...hof.#HofGeneratorFile] & [ // List comprehension
    for _, M in Datamodel.Modelsets.Custom.MigrateOrder
    {
      In: {
				MODEL: {
					M
          PackageName: "dm"
				}
      }
      TemplateName: "dm/model.go"
      Filepath: "\(Outdir)/dm/\(M.modelName).go"
    }
  ]

	// Routes
  _L1_RouteFiles: [...hof.#HofGeneratorFile] & list.FlattenN([[
    for _, R in Server.Routes
    {
      In: {
        ROUTE: {
          R
          PackageName: "routes"
        }
      }
      TemplateName: "route.go"
      Filepath: "\(OutdirConfig.ServerOutdir)/routes/\(In.ROUTE.name).go"
		}
	]], 1)

  _L2_RouteList: [ for P in _L1_RouteFiles if len(P.In.ROUTE.Routes) > 0 {
    [ for R in P.In.ROUTE.Routes { R,  Parent: { name: P.In.ROUTE.name } }]
  }]
  _L2_RouteFiles: [...hof.#HofGeneratorFile] & [ // List comprehension
    for _, R in list.FlattenN(_L2_RouteList, 1)
    {
      In: {
				ROUTE: {
					R
          PackageName: R.Parent.name
				}
      }
      TemplateName: "route.go"
      Filepath: "\(OutdirConfig.ServerOutdir)/routes/\(R.Parent.name)/\(R.name).go"
    }
  ]

  _L3_RouteList: [ for P in _L2_RouteFiles if len(P.In.ROUTE.Routes) > 0 {
    [ for R in P.In.ROUTE.Routes { R,  Parent: { name: P.In.ROUTE.name, Parent: P.In.ROUTE.Parent } }]
  }]
  _L3_RouteFiles: [...hof.#HofGeneratorFile] & [ // List comprehension
    for _, R in list.FlattenN(_L3_RouteList, 1)
    {
      In: {
				ROUTE: {
					R
          PackageName: R.Parent.name
				}
      }
      TemplateName: "route.go"
      Filepath: "\(OutdirConfig.ServerOutdir)/routes/\(R.Parent.Parent.name)/\(R.Parent.name)/\(R.name).go"
    }
  ]

	// Resource Routes
  _L1_ResourceFiles: [...hof.#HofGeneratorFile] & [
    for _, R in Server.Resources
    {
      In: {
        RESOURCE: {
          R
          PackageName: "resources"
        }
      }
      TemplateName: "resource.go"
      Filepath: "\(OutdirConfig.ServerOutdir)/resources/\(In.RESOURCE.name).go"
		}
	]

	...
}

