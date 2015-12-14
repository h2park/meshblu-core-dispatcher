_          = require 'lodash'
async      = require 'async'
UuidAliasResolver = require './uuid-alias-resolver'
JobManager = require 'meshblu-core-job-manager'
debug      = require('debug')('meshblu-core-dispatcher:queue-worker')
TaskRunner = require './task-runner'

class QueueWorker
  constructor: (options={}) ->
    {client,@timeout,@jobs,@jobRegistry,@pepper,aliasServerUri,@meshbluConfig} = options
    {@datastoreFactory,@cacheFactory} = options
    @client = _.bindAll client
    @timeout ?= 30
    @jobManager = new JobManager timeoutSeconds: @timeout, client: @client
    @uuidAliasResolver = new UuidAliasResolver
      cache: @cacheFactory.build 'uuid-alias'
      aliasServerUri: aliasServerUri

  run: (callback=->) =>
    debug 'running...'

    @jobManager.getRequest @jobs, (error, job) =>
      debug 'got job', error: error, job: job
      return callback error if error?
      return callback null unless job?
      @runJob job, callback

  runJob: (request={}, callback=->) =>
    return callback new Error("Missing metadata") unless request.metadata?
    {jobType,responseId} = request.metadata

    config = @jobRegistry[jobType]
    return callback new Error "jobType '#{jobType}' not found" unless config?

    options = {config, request, @datastoreFactory, @cacheFactory, @uuidAliasResolver, @pepper, @meshbluConfig}

    taskRunner = new TaskRunner options
    taskRunner.run (error, finishedJob) =>
      return callback error if error?
      @sendResponse jobType, responseId, finishedJob, callback

  sendResponse: (jobType, responseId, response, callback) =>
    debug 'sendResponse', jobType, response
    {metadata,rawData,data} = response

    newResponse =
      metadata:   metadata
      rawData:    rawData
      data:       data

    newResponse.metadata.responseId = responseId

    @jobManager.createResponse jobType, newResponse, callback

module.exports = QueueWorker
