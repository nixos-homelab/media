# Rows for an *arr app's grafana.nix, from exportarr's metrics: the health issues it reports, what's missing, free space on its
# root folders. `app` is the module and namespace (sonarr, radarr); `missing` the exportarr metric of what it lacks
{ g }:
{
  app,
  title,
  missing,
  wanted ? null,
}:
let
  j = ''job="${app}"'';
  health = g.table {
    title = "Health issues";
    description = "${title}'s own health checks";
    queries = [ (g.prom "${app}_system_health_issues{${j}}" { instant = true; }) ];
    noValue = "None";
  };
in
{
  overview = g.row { title = title; } (
    g.autoGrid { columns = 4; } (
      [
        (g.stat {
          title = "Health issues";
          decimals = 0;
          queries = [
            (g.prom "count(${app}_system_health_issues{${j}}) or vector(0)" { instant = true; })
          ];
        })
        (g.stat {
          title = "Missing";
          decimals = 0;
          queries = [ (g.prom "${missing}{${j}}" { instant = true; }) ];
        })
      ]
      ++ (
        if wanted == null then
          [ ]
        else
          [
            (g.stat {
              title = "Wanted";
              decimals = 0;
              queries = [ (g.prom "${wanted}{${j}}" { instant = true; }) ];
            })
          ]
      )
      ++ [
        (g.bargauge {
          title = "Free on root folders";
          unit = "bytes";
          queries = [
            (g.prom "${app}_rootfolder_freespace_bytes{${j}}" {
              instant = true;
              legend = "{{path}}";
            })
          ];
        })
      ]
    )
  );
  drilldown = g.row { title = title; } (
    g.autoGrid { columns = 2; } [
      health
      (g.timeseries {
        title = "Missing over time";
        decimals = 0;
        queries = [ (g.prom "${missing}{${j}}" { legend = "missing"; }) ];
      })
    ]
  );
}
