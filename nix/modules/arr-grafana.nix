# Panels for an *arr app's grafana.nix, from exportarr's metrics: how much of the library it has, what's missing, its
# health checks, the free space on its root folders. `app` is the module and namespace (sonarr, radarr); `missing`
# and `downloaded` the exportarr metrics of what it lacks and has, `item` what they count ("episodes"); `order` where
# its panels go on the Media dashboard
{ g, lib }:
{
  app,
  title,
  missing,
  downloaded,
  item,
  order,
}:
let
  j = ''job="${app}"'';
  toWorkload = [
    {
      title = title;
      url = "/d/workload/workload?var-workload=${app}&\${__url_time_range}";
    }
  ];
  library = {
    title = lib.toUpper (lib.substring 0 1 item) + lib.substring 1 (-1) item;
    description = "The monitored ${item} ${title} has, of all it wants (has and missing)";
    good = "sum(${downloaded}{${j}})";
    all = "sum(${downloaded}{${j}}) + sum(${missing}{${j}})";
    # A few missing is normal: orange under 95 %, red under 75 %
    warn = 0.95;
    crit = 0.75;
    links = toWorkload;
  };
  issues = {
    title = "${title} issues";
    description = "Problems ${title}'s own health checks report (an indexer down, a root folder missing, an update waiting); its Workload page lists them. Orange from 1, red from 3";
    decimals = 0;
    levels = g.levels {
      warn = 1;
      crit = 3;
    };
    links = toWorkload;
    queries = [ (g.prom "count(${app}_system_health_issues{${j}}) or vector(0)" { }) ];
  };
in
{
  # The Home dashboard's library graph, which the *arr apps share: a bar each
  home = {
    title = "Library completeness";
    description = "Downloaded / monitored items of each *arr app (has and missing)";
    type = "bargauge";
    unit = "percentunit";
    min = 0;
    max = 1;
    decimals = 1;
    options = {
      displayMode = "lcd";
      namePlacement = "top";
      sizing = "auto";
    };
    custom = { };
    order = 212;
    w = 6;
    h = 4;
    links = [
      {
        title = "Media";
        url = "/d/media/media?\${__url_time_range}";
      }
    ];
    series.${app} = {
      inherit order;
      query = g.prom (g.ratioExpr library.good library.all) {
        legend = "${library.title} {{good}}/{{all}}";
        instant = true;
      };
      overrides = [
        {
          matcher = {
            id = "byRegexp";
            options = "${library.title} .*";
          };
          properties = [
            {
              id = "color";
              value = {
                mode = "fixed";
                fixedColor = "purple";
              };
            }
          ];
        }
      ];
    };
  };
  # Two tiles for the Media dashboard's strip, at `order` and one after, and the library over time with the panels
  tiles = {
    "${app}-library" = {
      inherit order;
      w = 3;
      h = 4;
      panel = g.ratio (removeAttrs library [ "links" ]);
    };
    "${app}-health" = {
      order = order + 1;
      w = 3;
      h = 4;
      panel = g.stat (removeAttrs issues [ "links" ]);
    };
  };
  panels = {
    "${app}-activity" = {
      order = 100 + order;
      w = 8;
      h = 8;
      panel = g.timeseries {
        title = "${title} activity";
        description = "Events in ${title}'s history (releases grabbed, imported, deleted, failed) as bars; the library tile says how much of it is there";
        decimals = 0;
        noValue = "Nothing happened";
        custom = {
          drawStyle = "bars";
          fillOpacity = 70;
          lineWidth = 0;
        };
        queryOptions.maxDataPoints = 60;
        queries = [
          (g.prom "increase(${app}_history_total{${j}}[$__interval]) > 0" { legend = "events"; })
        ];
      };
    };
  };
  drilldown = g.row { title = title; } (
    g.pack [
      {
        w = 4;
        h = 4;
        panel = g.ratio library;
      }
      {
        w = 4;
        h = 4;
        panel = g.stat issues;
      }
      {
        w = 16;
        h = 8;
        panel = g.table {
          title = "Health issues";
          description = "${title}'s own health checks, as it words them";
          noValue = "None";
          queries = [
            (g.prom "max by (source, type, message) (${app}_system_health_issues{${j}})" { instant = true; })
          ];
          transformations = [
            {
              id = "organize";
              options.excludeByName = {
                Time = true;
                Value = true;
              };
            }
          ];
        };
      }
      {
        w = 8;
        h = 4;
        panel = g.bargauge {
          title = "Free on root folders";
          description = "The space left where ${title} puts the library";
          unit = "bytes";
          queries = [
            (g.prom "${app}_rootfolder_freespace_bytes{${j}}" {
              instant = true;
              legend = "{{path}}";
            })
          ];
        };
      }
    ]
  );
}
