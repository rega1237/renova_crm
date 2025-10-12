# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "sortablejs" # @1.15.6

pin "@fullcalendar/core", to: "https://cdn.skypack.dev/@fullcalendar/core@6.1.9"
pin "@fullcalendar/daygrid", to: "https://cdn.skypack.dev/@fullcalendar/daygrid@6.1.9"
pin "@fullcalendar/timegrid", to: "https://cdn.skypack.dev/@fullcalendar/timegrid@6.1.9"

# Charts library for interactive dashboard visuals (ESM-ready)
pin "apexcharts", to: "https://cdn.skypack.dev/apexcharts@3.46.0"
