#lang concourse/docs

@(require "common.rkt")

@title[#:version version #:tag "fly-cli"]{The Fly CLI}

The @code{fly} tool is a command line interface to Concourse. It is used for
a number of tasks from connecting to a shell in one of your build's
containers to uploading new pipeline configuration into a running Concourse.
Learning how to use @code{fly} will make using Concourse faster and more
useful.

You can download @code{fly} from a Concourse. There are download links for
common platforms in the bottom right hand corner of the main page.

@section{Targeting your Concourse}

Fly works with an already deployed Concourse. If you don't already have one of
these you should follow the @seclink["deploying-with-vagrant"]{Deploying
with Vagrant} or @seclink["deploying-with-bosh"]{Deploying with BOSH} guides
to deploy a Concourse.

Once you've deployed Concourse you can tell @code{fly} to target it via the
@code{--target} flag. For example, if we wanted to run @code{fly sync} (don't
worry what this means just yet) while pointing at Concourse that you normally
reach by going to @code{http://ci.example.com} then you could run:

@codeblock["sh"]|{
$ fly --target 'http://ci.example.com' sync
}|

@margin-note{
  The default Vagrant address is set as the default target in @code{fly}. This
  means that you don't need to do anything extra if you are using the Vagrant
  boxes to deploy Concourse.
}

The single quotes aren't always required, but if you need to put HTTP basic
authentication credentials inline, then they can help by avoiding the need to
escape special characters in passwords. For example:

@codeblock["sh"]|{
$ fly --target 'http://username:p@$$w0rd@ci.example.com' sync
}|

If your Concourse uses SSL but does not have a CA signed certificate, you
can use the @code{-k} or @code{--insecure} flag in order to make @code{fly}
not check the remote certificates.

For the rest of this document it is assumed you are setting the target in
each of the commands and so it will not be included for brevity.

@section[#:tag "fly-save-target"]{@code{save-target}@aux-elem{: Saving Concourse Targets}}

Using @code{save-target} allows you to save a named target to a @code{.flyrc}
file stored in your home directory, so that you don't have to repeat the full
URL for every command. Passing the name of a saved target via @code{--target}
(or @code{-t} for short) will look up its details from your @code{.flyrc} and
use them in the call specified.

The @code{--api} flag and a target name are the only two properties required
to save a target:

@codeblock["sh"]|{
$ fly save-target --api https://example.com my-target
}|

The full set of properties can be specified as such:

@codeblock["sh"]|{
$ fly save-target --api https://example.com --username my-user
--password my-password my-target
}|

@section[#:tag "fly-execute"]{@code{execute}@aux-elem{: Submitting Local Tasks}}

One of the most common use cases of @code{fly} is taking a local project on
your computer and submitting it up with a task configuration to be run
inside a container in Concourse. This is useful to build Linux projects on
OS X or to avoid all of those debugging commits when something is configured
differently between your local and remote setup.

If you have a task configuration called @code{task.yml} that describes a
task that only requires a single input, whose contents are in the current
directory (e.g. most unit tests and simple integration tests) then you can
just run:

@codeblock["sh"]|{
$ fly execute
}|

Your files will be uploaded and the task will be executed with them. The
working directory name will be used as the input name. If they do not match,
you must specify @code{-i name=.} instead, where @code{name} is the input
name from the task configuration.

Fly will automatically capture @code{SIGINT} and @code{SIGTERM} and abort the
build when received. This allows it to be transparently composed with other
toolchains.

If your task configuration is in a non-standard location then you can
specify it using the @code{-c} or @code{--config} argument like so:

@codeblock["sh"]|{
$ fly execute -c tests.yml
}|

If you have many extra files or large files in your currect directory that
would normally be ignored by your version control system, then you can use
the @code{-x} or @code{--exclude-ignored} flags in order to limit the files
that you send to Concourse to just those that are not ignored.

If your task needs to run as @code{root} then you can specify the @code{-p}
or @code{--privileged} flag.

@subsection{Multiple Inputs to Locally Submitted Tasks}

Tasks in Concourse can take multiple inputs. Up until now we've just been
submitting a single input (our current working directory) that has the same
name as the directory.

Tasks must specify the inputs that they require (for more information, refer
to the @seclink["configuring-tasks"]{configuring tasks} documentation). For
@code{fly} to upload these inputs you can use the @code{-i} or
@code{--input} arguments with name and path pairs. For example:

@codeblock["sh"]|{
$ fly execute -i code=. -i stemcells=../stemcells
}|

This would work together with a @code{task.yml} if its @code{inputs:}
section was as follows:

@codeblock["yaml"]|{
inputs:
- name: code
- name: stemcells
}|

If you specify an input then the default input will no longer be added
automatically and you will need to explicitly list it (as with the
@code{code} input above).

This feature can be used to mimic other resources and try out combinations
of input that would normally not be possible in a pipeline.

@section[#:tag "fly-configure"]{@code{configure}@aux-elem{: Configuring Pipelines}}

Fly can be used to fetch and update the configuration for your pipelines. This
is achieved by using the @code{configure} command. For example, to fetch the
current configuration of your @code{my-pipeline} Concourse pipeline and print
it on @code{STDOUT} run the following:

@codeblock["sh"]|{
$ fly configure my-pipeline
}|

To get JSON instead of YAML you can use the @code{-j} or @code{--json}
argument. This can be useful when inspecting your config with
@hyperlink["http://stedolan.github.io/jq/"]{jq}.

To submit a pipeline configuration to Concourse from a file on your local disk
you can use the @code{-c} or @code{--config} flag, like so:

@codeblock["sh"]|{
$ fly configure --config pipeline.yml my-pipeline
}|

This will present a diff of the changes and ask you to confirm the changes.
If you accept then Concourse's pipeline configuration will switch to the
pipeline definition in the YAML file specified.

@subsection[#:tag "parameters"]{Parameters}

The pipeline configuration can contain templates in the form of
@code{{{foo-bar}}}. They will be replaced with string values populated by
repeated @code{--var} or @code{--vars-from} flags.

This allows for credentials to be extracted from a pipeline config, making it
safe to check in to a public repository or pass around.

For example, if you have a @code{pipeline.yml} as follows:

@codeblock["yaml"]|{
resources:
- name: private-repo
  type: git
  source:
    uri: git@...
    branch: master
    private_key: {{private-repo-key}}
}|

...you could then configure this pipeline like so:

@codeblock["sh"]|{
$ fly configure --config pipeline.yml --var "private-repo-key=$(cat id_rsa)" my-pipeline
}|

Or, if you had a @code{credentials.yml} as follows:

@codeblock["yaml"]|{
private-repo-key: |
  -----BEGIN RSA PRIVATE KEY-----
  ...
  -----END RSA PRIVATE KEY-----
}|

...you could configure it like so:

@codeblock["sh"]|{
$ fly configure --config pipeline.yml --vars-from credentials.yml my-pipeline
}|

If both @code{--var} and @code{--vars-from} are specified, the @code{--var}
flags take precedence.


@section[#:tag "fly-destroy-pipeline"]{@code{destroy-pipeline}@aux-elem{: Removing Pipelines}}

Every now and then you just don't want a pipeline to be around anymore.
Running @code{fly destroy-pipeline} will stop the pipeline activity and remove
all data collected by the pipeline, including build history and collected
versions.


@section[#:tag "fly-intercept"]{@code{intercept}@aux-elem{: Accessing a running or recent build's steps}}

Sometimes it's helpful to be on the same machine as your tasks so that you
can profile or inspect them as they run or see the state the machine at the
end of a run. Due to Concourse running tasks in containers on remote
machines this would typically be hard to access. To this end, there is a
@code{fly intercept} command that will give you a shell inside the most
recent one-off build that was submitted to Concourse. For example, running
the following will run a task and then enter the finished task's
container:

@margin-note{
  Be warned, if more than one person is using a Concourse server for running
  one-off builds then you may end up in a build that you did not expect!
}

@codeblock["sh"]|{
$ fly execute
$ fly intercept
}|

Containers are around for a short time after a build in order to allow
people to intercept them.

You can also intercept builds that were run in your pipeline. By using the
@code{-j} or @code{--job} and @code{-b} or @code{--build} you can pick out a
specific job and build to intercept.

The shell created on the remote container via @code{fly intercept} provides
root user access by default.

@margin-note{
  The command @code{fly hijack} is an alias of @code{fly intercept}. Both can
  be used interchangably.
}

@centered{
  @image["images/fly-demo.png"]{Fly Demo}
}

A specific command can also be given, e.g. @code{fly intercept ps auxf} or
@code{fly intercept htop}. This allows for patterns such as @code{watch fly
intercept ps auxf}, which will continuously show the process tree of the
current build's task, even as the "current build" changes.

@section[#:tag "fly-sync"]{@code{sync}@aux-elem{: Update your local copy of @code{fly}}}

Occasionally we add additional features to @code{fly} or make changes to the
communiction between it and Concourse's API server. To make sure you're
running the latest and greatest version that works with the Concourse you
are targeting we provide a command called @code{sync} that will update your
local @code{fly}. It can be used like so:

@codeblock["sh"]|{
$ fly sync
}|

@section[#:tag "fly-watch"]{@code{watch}@aux-elem{: View logs of in-progress builds}}

Concourse emits streaming colored logs on the website but it can be helpful
to have the logs availiable to the command line. (e.g. so that they can be
processed by other commands).

The @code{watch} command can be used to do just this. You can also view
builds that were run in your pipeline. By using the @code{-j} or
@code{--job} and @code{-b} or @code{--build} you can pick out a specific job
and build to watch. For example, the following command will either show the
archived logs for an old build if it has finished running or it will stream
the current logs if the build is still in progress.

@codeblock["sh"]|{
$ fly watch --job tests --build 52
}|

@inject-analytics[]
