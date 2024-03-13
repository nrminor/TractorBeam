module TractorBeam

using ArgParse
using Base.Threads: @threads
using Logging
using Pipe: @pipe
using ResultTypes: @try
using MD5
using YAML

export Credentials,
    TransferFile,
    TransferQueue,
    generate_config,
    interpolate_remote,
    parse_config,
    run_transfer,
    oversee_transfers

"""
"""
struct Credentials
    address::String
    username::String
    remote_dir::String
end

"""
"""
mutable struct TransferFile
    relative_path::String
    dest_path::String
    origin_hash::String
    destination_hash::String
end

"""
"""
mutable struct TransferQueue
    files::Vector{TransferFile}
    member_count::Int
    remaining::Int
    progress::Float32
end

"""
"""
function generate_config(config_path::String)
    @assert isfile(config_path) "Provided config file name/path does not exist."
    yaml_name = "tractorbeam.yml"
    run(
        pipeline(`pkl eval --format yaml $config_path`, yaml_name)
    )

    return yaml_name
end
precompile(generate_config, (String,))

"""
"""
function interpolate_remote(
    username::String,
    address::String,
    remote_dir::String,
    file_path::String,
)
    return "$(username)@$(address):$(remote_dir)/$(file_path)"
end
precompile(interpolate_remote, (String, String, String, String))

"""
"""
function parse_config(yaml_name::String)
    # load the YAML with strict type enforcement (Pkl should already be
    # taking care of this, but it doesn't hurt to double-check)
    config_dict = YAML.load_file(yaml_name; dicttype = Dict{Symbol, String})

    credentials = Credentials(
        config_dict[:address],
        config_dict[:username],
        config_dict[:remote_dir],
    )
    command = config_dict[:command]

    return (credentials, command)
end
precompile(parse_config, (String,))

"""
"""
function run_transfer(source_path::String, destination::String)
    run(`rsync -aqz $(source_path) $(destination)`; wait = false)
    return
end
precompile(run_transfer, (String, String))

"""
"""
function oversee_transfers(
    queue::TransferQueue,
    creds::Credentials,
    to_or::Bool,
)
    # print a warning if running on a single thread
    if Threads.nthreads() < 2
        @warn "TractorBeam appears to be running on a single thread, meaning that only one file can be transferred at a time. Performance may be slow."
    end

    # run as many transfers as there are CPU cores available to the Julia runtime
    @threads for (i, file) in enumerate(queue.files)
        if to_or
            transfer_to_hpc(file, creds)
            continue
        end

        transfer_from_hpc(file, creds)

        # this will probably cause a data race but oh well
        queue.remaining = queue.member_count - i
        queue.progress = queue.remaining / queue.member_count
    end
end
precompile(oversee_transfers, (TransferQueue, Bool))

end # module TractorBeam
