#lang concourse/docs

@(require "../common.rkt")

@title[#:tag "versioned-s3-artifacts" #:version version]{Versioned S3 Artifacts}

This document will guide you through a pipeline modeled on a fairly common
real-world use case of pushing tested artifacts into S3 buckets.

The resulting pipeline will look like this:

@image[#:style "pipeline" #:suffixes '(".svg") "examples/versioned-s3-artifacts"]{Rendered Pipeline}

@literate[
  @literate-segment[
    @para{
      First, we'll define our resources. These are the @emph{objects} used in
      our pipeline. The @code{resources} configuration simply enumerates each
      of their locations.
    }
    @codeblock["yaml"]{
      @||resources:
    }
  ]

  @literate-segment[
    @para{
      Our first resource will be the location of our product's source code.
      Let's pretend it lives in a Git repo, and so we'll use the
      @hyperlink["https://github.com/concourse/git-resource"]{@code{git}
      resource type}.
    }
    @para{
      The @code{git} resource type requires two source parameters: @code{uri}
      and @code{branch}. We're using a SSH URI, so we'll also need to specify
      @code{private_key}.
    }
    @para{
      To avoid embedding credentials in the pipeline config, we'll use
      a @seclink["parameters"]{parameter}.
    }
    @codeblock["yaml"]{
      @||- name: my-product
      @||  type: git
      @||  source:
      @||    uri: git@"@"github.com:my-user/my-product.git
      @||    branch: master
      @||    private_key: {{my-product-github-private-key}}
    }
  ]

  @literate-segment[
    @para{
      We'll need a resource to represent the semantic version of our product,
      which we'll use to generate release candidates, and bump every time we
      ship. For this we'll use the
      @hyperlink["https://github.com/concourse/semver-resource"]{@code{semver}
      resource type}.
    }
    @para{
      Currently, @code{semver} resources keep track of the version as a file
      in a S3 bucket, so we'll need to specify the credentials for the bucket,
      and a name for the file.
    }
    @para{
      If your product already has a version number, you can specify it as
      @code{initial_version}. If not specified, the version will start as
      @code{0.0.0}.
    }
    @codeblock["yaml"]{
      @||- name: version
      @||  type: semver
      @||  source:
      @||    bucket: my-product-pipeline-artifacts
      @||    key: current-version
      @||    access_key_id: {{s3-access-key-id}}
      @||    secret_access_key: {{s3-secret-access-key}}
      @||    initial_version: 1.0.0
    }
  ]

  @literate-segment[
    @para{
      Let's define the resource for storing our product's release candidate
      artifacts generated by the pipeline. This is done with the
      @hyperlink["https://github.com/concourse/s3-resource"]{@code{s3}
      resource type}.
    }
    @para{
      The @code{s3} resource type is minimally configured with a @code{bucket}
      name and a @code{regexp}, which will be used to match files in the
      bucket and order them by the version number extracted by the first
      capture group.
    }
    @para{
      Since we'll be writing objects into this bucket, we'll need to configure
      it with AWS credentials.
    }
    @codeblock["yaml"]{
      @||- name: my-product-rc
      @||  type: s3
      @||  source:
      @||    bucket: my-product-pipeline-artifacts
      @||    regexp: my-product-(.*).tgz
      @||    access_key_id: {{s3-access-key-id}}
      @||    secret_access_key: {{s3-secret-access-key}}
    }
  ]

  @literate-segment[
    @para{
      We'll need one more @code{s3} resource to represent shipped artifacts.
    }
    @codeblock["yaml"]{
      @||- name: my-product-final
      @||  type: s3
      @||  source:
      @||    bucket: my-product
      @||    regexp: my-product-(.*).tgz
      @||    access_key_id: {{s3-access-key-id}}
      @||    secret_access_key: {{s3-secret-access-key}}
    }
  ]

  @literate-segment[
    @para{
      Now that we've got all our resources defined, let's move on define the
      @emph{functions} to apply to them, as represented by @code{jobs}
    }
    @codeblock["yaml"]{
      @||jobs:
    }
  ]

  @literate-segment[
    @para{
      Our first job will run the unit tests for our project. This job will
      fetch the source code, using the @secref{get-step} step with the
      @code{my-product} resource, and execute the
      @seclink["configuring-tasks"]{Task configuration file} living in the
      repo under @code{ci/unit.yml} using a @secref{task-step} step.
    }
    @para{
      We set @code{trigger: true} on the @secref{get-step} step so that it
      automatically triggers a new @code{unit} build whenever new commits are
      pushed to the @code{my-product} repository.
    }
    @codeblock["yaml"]{
      @||- name: unit
      @||  plan:
      @||  - get: my-product
      @||    trigger: true
      @||  - task: unit
      @||    file: my-product/ci/unit.yml
    }
  ]

  @literate-segment[
    @para{
      Our pipeline now does something! But we're not quite delivering
      artifacts yet.
    }
  ]

  @literate-segment[
    @para{
      Let's consider anything making it past the unit tests to be a candidate
      for a new version to ship. We'll call the job that builds candidate
      artifacts @code{build-rc}.
    }
    @para{
      Note that for jobs like this you'll want to specify @code{serial: true}
      to ensure you're not accidentally generating release candidates out of
      order.
    }
    @codeblock["yaml"]{
      @||- name: build-rc
      @||  serial: true
      @||  plan:
    }
  ]

  @literate-segment[
    @para{
      First, let's be sure to only grab versions of @code{my-product} that
      have passed unit tests. Let's have new occurrences of these versions
      also trigger new builds, while we're at it.
    }
    @codeblock["yaml"]{
      @||  - get: my-product
      @||    passed: [unit]
      @||    trigger: true
    }
  ]

  @literate-segment[
    @para{
      We'll also need a new release candidate version number. For this, the
      @hyperlink["https://github.com/concourse/semver-resource"]{@code{semver}}
      resource type can be used to generate versions by specifying params in
      the @secref{get-step} step.
    }
    @para{
      Specifying @code{bump: minor} and @code{pre: rc} makes it so that if the
      current version is e.g. @code{1.2.3-rc.3}, we'll get @code{1.2.3-rc.4}.
      If not, the version will receive a minor bump, and we'll get something
      like @code{1.3.0-rc.1}.
    }
    @codeblock["yaml"]{
      @||  - get: version
      @||    params: {bump: minor, pre: rc}
    }
  ]

  @literate-segment[
    @para{
      Now, we'll execute our @code{build-artifact} task configuration, which
      we'll assume has two inputs (@code{my-product} and @code{version}) and
      produces a file named @code{my-product-{VERSION}.tgz} when executed.
    }
    @codeblock["yaml"]{
      @||  - task: build-artifact
      @||    file: my-product/ci/build-artifact.yml
    }
  ]

  @literate-segment[
    @para{
      Now that we have a tarball built, let's @secref{put-step} it up to the
      pipeline artifacts S3 bucket via the @code{my-product-rc} resource
      defined above.
    }
    @para{
      Note that we refer to the task that generated the @code{.tgz} in the
      path specified by the @code{from} param.
    }
    @codeblock["yaml"]{
      @||  - put: my-product-rc
      @||    params: {from: build-artifact/my-product-.*.tgz}
    }
  ]

  @literate-segment[
    @para{
      We'll also need to push up the newly bumped version number, so that next
      time we bump it'll be based on this new one.
    }
    @para{
      Note that the @code{file} param points at the version created by the
      @code{version} step above.
    }
    @codeblock["yaml"]{
      @||  - put: version
      @||    params: {file: version/number}
    }
  ]

  @literate-segment[
    @para{
      Now we're cooking with gas. But still, we haven't shipped any actual
      versions of the project yet: only candidates! Let's move on to the later
      stages in the pipeline.
    }
  ]

  @literate-segment[
    @para{
      Let's assume there's some more resource-intensive integration suite that
      uses our product, as a black-box. This will be the final set of checks
      and balances before shipping actual versions.
    }
    @para{
      Let's assume this suite has to talk to some external environment, and so
      we'll configure the job with @code{serial: true} here to prevent
      concurrent builds from polluting each other.
    }
    @codeblock["yaml"]{
      @||- name: integration
      @||  serial: true
      @||  plan:
    }
  ]

  @literate-segment[
    @para{
      For the integration job, we'll need two things: the candidate artifact,
      and the repo that it came from, which contains all our CI scripts.
    }
    @para{
      Note that this usage of @code{passed} guarantees that the two versions
      of @code{my-product} and @code{my-product-rc} respectively came out from
      the @emph{same build} of @code{build-rc}. See @secref{get-step} for more
      information.
    }
    @codeblock["yaml"]{
      @||  - get: my-product-rc
      @||    trigger: true
      @||    passed: [build-rc]
      @||  - get: my-product
      @||    passed: [build-rc]
    }
  ]

  @literate-segment[
    @para{
      We'll now run the actual integration task. Since it has to talk to some
      external environment, we'll use @code{config.params} to forward its
      credentials along to the task. See @secref{task-step} for more
      information.
    }
    @para{
      Again we'll use @seclink["parameters"]{parameters} in the config file to
      prevent hardcoding them.
    }
    @codeblock["yaml"]{
      @||  - task: integration
      @||    file: my-product/ci/integration.yml
      @||    config:
      @||      params:
      @||        API_ENDPOINT: {{integration-api-endpoint}}
      @||        ACCESS_KEY: {{integration-access-key}}
    }
  ]

  @literate-segment[
    @para{
      At this point in the pipeline we have artifacts that we're ready to
      ship. So let's define a job that, when manually triggered, takes the
      latest candidate release artifact and publishes it to the S3 bucket
      containing our shipped product versions.
    }
  ]

  @literate-segment[
    @para{
      We'll call the job @code{shipit} and make sure it only runs serially,
      since it's mutating external resources. This won't matter too much in
      practice though, since the job will only ever be manually triggered.
    }
    @codeblock["yaml"]{
      @||- name: shipit
      @||  serial: true
      @||  plan:
    }
  ]

  @literate-segment[
    @para{
      Similar to the @code{integration} job, we'll once again need both our
      source code and the latest release candidate, this time having passed
      @code{integration} together.
    }
    @para{
      Note that we have not specified @code{trigger: true} this time - this is
      because with a typical release-candidate pipeline, the shipping stage is
      only ever manually kicked off.
    }
    @codeblock["yaml"]{
      @||  - get: my-product-rc
      @||    passed: [integration]
      @||  - get: my-product
      @||    passed: [integration]
    }
  ]

  @literate-segment[
    @para{
      Now we'll need to determine the final version number that we're about to
      ship. This is once again done by specifying @code{params} when fetching
      the version.
    }
    @para{
      This time, we'll only specify @code{bump} as @code{final}. This means
      "take the version number and chop off the release candidate bit."
    }
    @codeblock["yaml"]{
      @||  - get: version
      @||    params: {bump: final}
    }
  ]

  @literate-segment[
    @para{
      Next, we'll need to convert the release candidate artifact to a final
      version.
    }
    @para{
      This step depends on the type of product you have; in the simplest case
      it's just a matter of renaming the file, but you may also have to
      rebuild it with the new version number, or push dependent files, etc.
    }
    @para{
      For the purposes of this example, let's assume we have a magical task
      that does it all for us, and leaves us with a file called
      @code{my-product-{VERSION}.tgz}, just as with the @code{build-rc} job
      before.
    }
    @codeblock["yaml"]{
      @||  - task: promote-to-final
      @||    file: my-product/ci/promote-to-final.yml
    }
  ]

  @literate-segment[
    @para{
      And now for the actual shipping!
    }
    @codeblock["yaml"]{
      @||  - put: my-product-final
      @||    params: {from: promote-to-final/my-product-.*.tgz}
      @||  - put: version
      @||    params: {from: version/number}
    }
  ]
]

@inject-analytics[]
