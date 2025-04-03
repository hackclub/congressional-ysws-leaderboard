GoodJob::Engine.middleware.use(Rack::Auth::Basic) do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(Rails.application.credentials.good_job.password, password)
end

Rails.application.configure do
  # Configure GoodJob scheduler
  # Docs: https://github.com/bensheldon/good_job#scheduling-cron
  config.good_job.cron = {
    import_representatives: {
      cron: '0 0 * * 0', # Every Sunday at midnight
      class: 'ImportRepresentativesJob'
    },
    sync_ysws_projects: {
        cron: '45 * * * *', # Every hour at 45 minutes past the hour
        class: 'Ysws::SyncProjectsJob'
    }
    # Add other recurring jobs here
  }
end 