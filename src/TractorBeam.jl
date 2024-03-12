module TractorBeam

export Credentials, Command, TransferFile, TransferQueue

"""
"""
struct Credentials
    address::String
    username::String
    password::String
    remote_dir::String
end

"""
"""
struct Command
    in_path::String
    out_path::String
    config_path::String
    command::String
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

end # module TractorBeam
