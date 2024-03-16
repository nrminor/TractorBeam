#!/usr/bin/env -S julia --threads auto --gcthreads=3 --compile=all --optimize=3

module TractorBeam

using AbbreviatedStackTraces
using Base.Iterators
using Base.Threads: @threads
using Logging
using Pipe: @pipe
using MD5
using YAML


export Credentials,
    TransferFile,
    TransferQueue,
    generate_config,
    interpolate_remote,
    parse_config,
    make_local_file_queue,
    oversee_transfers,
    run_remote_command,
    make_result_file_queue

"""
    Credentials

A `struct` that encapsulates the necessary credentials and information required
for connecting to and interacting with a remote host. This includes the remote
host's address, the username for authentication, and the base directory on the
remote host where operations such as file transfers and command execution will
take place.

### Fields

- `address::String`: The network address of the remote host. This can be an IP
address or a domain name.
- `username::String`: The username used for authentication with the remote host.
It is assumed that the corresponding authentication method (e.g., SSH keys) is
properly configured.
- `remote_dir::String`: The absolute path to the base directory on the remote
host. This directory is the root for any file transfer operations and may also
serve as the working directory for remote command execution.

### Usage

The `Credentials` struct is intended to be instantiated with the required fields
and passed to functions or methods that require access to the remote host. It
centralizes the authentication details and remote directory information,
facilitating easier management of remote operations throughout the project.
"""
struct Credentials
    address::String
    username::String
    remote_dir::String
end


"""
    TransferFile

A `mutable struct` that represents a file to be transferred between a local
machine and a remote host, including the necessary metadata for verifying
the integrity of the transfer. This struct is designed to track the source
and destination paths of the file, as well as hash values for integrity checks
before and after the transfer.

### Fields

- `source_path::String`: The absolute path to the file on the source system
(local machine). This path is used as the starting point for the transfer 
operation.
- `dest_path::String`: The intended absolute path to the file on the 
destination system (remote host). This path indicates where the file should be
placed after the transfer.
- `origin_hash::String`: A hash value (e.g., SHA-256) representing the file's
content at the source. This is used to verify the file's integrity before the
transfer begins.
- `destination_hash::String`: A hash value (e.g., SHA-256) representing the
file's content at the destination after the transfer. This is used to verify
that the file was transferred correctly and has not been altered or corrupted.

### Usage

Instances of `TransferFile` are used to manage and verify file transfers 
between the local system and a remote host. By tracking both the paths and hash
values, the struct allows for robust integrity checks, ensuring that files are
transferred accurately and securely.

This struct is mutable, allowing for the `destination_hash` to be updated after
the file transfer is complete, facilitating a comparison between `origin_hash`
and `destination_hash` to confirm the integrity of the transferred file.
"""
mutable struct TransferFile
    source_path::String
    dest_path::String
    origin_hash::String
    destination_hash::String
end


"""
    TransferQueue

A `mutable struct` designed to manage a queue of files (`TransferFile`
instances) that are scheduled for transfer between a local machine and a remote
host. It encapsulates the queue of files to be transferred and provides metadata
for tracking the overall progress of the transfer operation.

### Fields
- `files::Vector{TransferFile}`: A vector of `TransferFile` instances, each
representing a file to be transferred, including its source and destination
paths and hash values for integrity verification.
- `member_count::Int`: The total number of files initially queued for transfer.
This value is set at the creation of the `TransferQueue` instance and typically
does not change, serving as a reference for the total scope of the transfer
operation.
- `remaining::Int`: The number of files yet to be transferred at any given
point in time. This value decreases as files are successfully transferred,
reaching 0 when all transfers are complete.
- `progress::Float32`: A floating-point value representing the percentage of
the transfer operation that has been completed. This is typically calculated
as a ratio of `(member_count - remaining) / member_count` and updated as
files are transferred.

### Usage
`TransferQueue` is utilized to organize and monitor the progress of bulk file
transfer operations. By keeping track of both the individual files (`files`
vector) and aggregate metadata (`member_count`, `remaining`, `progress`),
it facilitates efficient management and real-time monitoring of the transfer
process.

The mutability of the struct allows for dynamic updates to the `remaining`
and `progress` fields as files are transferred, offering a live view into
the operation's progress.

### Example
```julia
# Assuming TransferFile definitions are available
queue = TransferQueue(
    [TransferFile("src1", "dest1", "hash1", ""),
    TransferFile("src2", "dest2", "hash2", "")],
    2, 2, 0.0)
# As files are transferred, update `remaining` and `progress`
queue.remaining -= 1
queue.progress = (queue.member_count - queue.remaining) / queue.member_count
````
"""
mutable struct TransferQueue
    files::Vector{TransferFile}
    member_count::Int
    remaining::Int
    progress::Float32
end


"""
    generate_config(config_path::String)::String

Generates a YAML configuration file from a given `.pkl` (Pickle) file. This
function asserts the existence of the specified `.pkl` file, then utilizes an
external tool to evaluate and convert the `.pkl` file into a YAML format. The
generated YAML file is intended to be used as a configuration file for further
operations within the project.

### Parameters
- `config_path::String`: The file path to the input configuration file in Pkl
format.

### Returns
- `yaml_name::String`: The name of the generated YAML file. This function is
currently hardcoded to return a fixed file name `"tractorbeam.yml"`, assuming
the YAML file is created in the current working directory.

### Behavior
- The function first checks if the provided `config_path` points to an existing
file. If the file does not exist, it throws an assertion error, halting
execution with a message indicating the issue.
- Upon successfully verifying the existence of the `.pkl` file, the function
then calls an external command (`/usr/local/bin/pkl eval --format yaml`) to
convert the `.pkl` file to YAML format. The output is directed to a new file
named `"tractorbeam.yml"`.
- The name of the newly created YAML file is then returned by the function.

### Example Usage
```julia
yaml_config = generate_config("path/to/config.pkl")
# yaml_config would be "tractorbeam.yml", indicating the YAML file has been created.
```
"""
function generate_config(config_path::String)
    @assert isfile(config_path) "Provided config file name/path does not exist."
    yaml_name = "tractorbeam.yml"
    run(
        pipeline(
            `/usr/local/bin/pkl eval --format yaml $config_path`,
            yaml_name,
        ),
    )

    return yaml_name
end
precompile(generate_config, (String,))


"""
    interpolate_remote

Constructs a string that represents a remote file path in a format compatible
with various remote access tools (e.g., SSH, SCP, Rsync). This function
interpolates the given username, address, and file path into a single string,
facilitating remote file operations.

### Parameters
- `username::String`: The username for accessing the remote system. This is
the user under which the remote operations will be executed.
- `address::String`: The network address of the remote system. This can be a
hostname or an IP address.
- `file_path::String`: The absolute path to the file on the remote system. This
path should be accessible by the provided `username`.

### Returns
- A string in the format `"username@address:file_path"`. This string can be used
as an identifier for remote files in commands that support remote operations,
such as `scp`, `rsync`, or remote `ssh` command execution.

### Example Usage
```julia
remote_path = interpolate_remote("user123", "example.com", "/home/user123/data.txt")
# remote_path will be "user123@example.com:/home/user123/data.txt"
"""
function interpolate_remote(
    username::String,
    address::String,
    file_path::String,
)
    return "$(username)@$(address):$(file_path)"
end
precompile(interpolate_remote, (String, String, String))


"""
    parse_config

Reads and parses a YAML configuration file, extracting essential information
for remote file operations, including credentials, directories, and command to
execute on the remote host.

### Parameters
- `yaml_name::String`: The file path to the YAML configuration file. This file
should specify details such as the remote address, username, remote working
directory, local results directory, inputs to transfer, and the command to execute.

### Returns
- A tuple containing:
    - `credentials::Credentials`: A `Credentials` struct populated with the
    remote host's address, username, and remote working directory.
    - `local_dir::String`: The path to the local directory containing input
    files to be transferred.
    - `results_dir::String`: The path to the local directory where results
    should be downloaded.
    - `command::String`: The command to be executed on the remote host.

### Behavior
- The function first loads the YAML configuration file, enforcing strict type
checks to ensure the configuration adheres to the expected structure and types.
- It then extracts necessary details from the configuration dictionary to
instantiate a `Credentials` struct and identify relevant local and remote
directories and the command for remote execution.
- The extracted information is returned as a tuple, facilitating further
processing in the workflow.

### Example Usage
```julia
credentials, local_dir, results_dir, command = parse_config("config.yml")
# Use the extracted information for file transfers and remote command execution
```
"""
function parse_config(yaml_name::String)
    # load the YAML with strict type enforcement (Pkl should already be
    # taking care of this, but it doesn't hurt to double-check)
    config_dict = YAML.load_file(yaml_name; dicttype = Dict{String, Any})

    credentials = Credentials(
        config_dict["address"],
        config_dict["username"],
        config_dict["remote_working_dir"],
    )
    results_dir = config_dict["local_results_dir"]
    local_dir = config_dict["inputs_to_transfer"]
    command = config_dict["command"]

    return (credentials, local_dir, results_dir, command)
end
precompile(parse_config, (String,))


"""
    make_local_file_queue(dir_to_send::String, remote_dir::String)::TransferQueue

Creates a queue (`TransferQueue`) of files (`TransferFile` instances) to be
transferred from a local directory to a specified directory on a remote host.
This function scans the given local directory for all files (excluding certain
system files) and prepares them for transfer by encapsulating each file's path
and target destination in a `TransferFile` struct.

### Parameters
- `dir_to_send::String`: The path to the local directory containing files to be
transferred. This directory is recursively scanned for files.
- `remote_dir::String`: The target directory on the remote host where the files
should be transferred. This is used to construct the destination path for each
file in the `TransferFile` struct.

### Returns
- `TransferQueue`: An instance of the `TransferQueue` struct containing a queue
of `TransferFile` instances ready for transfer. Each `TransferFile` includes
the local source path and the intended remote destination path, while hash
values for integrity checks are initially left blank.

### Workflow
1. **Directory Walking**: Recursively walks through `dir_to_send`, collecting
all file paths while excluding system files (e.g., `.DS_Store`) and hidden
files starting with `._`.
2. **Path Processing**: Processes each file path to create a list of relative
paths from `dir_to_send`.
3. **Queue Preparation**: For each file identified, a `TransferFile` instance
is created with the source path set to the file's relative path and the
destination path set to `remote_dir`. Integrity check hashes are not generated
at this stage.
4. **Queue Assembly**: All `TransferFile` instances are aggregated into a
`TransferQueue`, which also records the total number of files and initializes
progress to `0.0`.
"""
function make_local_file_queue(
    dir_to_send::String,
    remote_dir::String,
)::TransferQueue

    # use a functional programming style pipeline to collect a vector of
    # all the local relative paths for all the files that will be sent.
    rel_paths = @pipe walkdir(dir_to_send) |>
          map(x -> [x[1], x[3]], _) |>
          flatmap(x -> [joinpath(x[begin], file) for file in x[end]], _) |>
          collect |>
          filter(
              x ->
                  !contains(x, ".DS_Store") & isfile(x) & !startswith(x, "._"),
              _,
          )

    # TODO
    # generate hashes for all the files to be transferred

    # create a vector of TransferFile instances that will themselves be
    # contained in an instance of the TransferQueue struct
    transfer_files = [
        TransferFile(source_path, remote_dir, "", "") for
        source_path in rel_paths
    ]

    # return the TransferQueue
    return TransferQueue(
        transfer_files,
        length(transfer_files),
        length(transfer_files),
        0.0,
    )
end
precompile(make_local_file_queue, (String, String))


"""
    transfer_to_remote(input_file::TransferFile, credentials::Credentials)

Initiates an asynchronous transfer of a single file to a remote destination
using the provided credentials. This function logs the transfer attempt,
verifies the existence of the source file, interpolates the destination path,
and performs the transfer using `rsync`. Post-transfer, it calculates the MD5
hash of the source file to facilitate future integrity checks.

### Parameters
- `input_file::TransferFile`: An instance of `TransferFile` representing the
file to be transferred, including its source path, destination path, and
placeholders for hash values.
- `credentials::Credentials`: An instance of `Credentials` providing the
authentication details required for the remote transfer, including username,
    address, and the remote directory path.

### Behavior
- **Logging**: Outputs an informational message indicating the transfer start,
utilizing the current thread ID for asynchronous operation tracking.
- **Existence Check**: Asserts the existence of the source file to ensure the
file path is valid before attempting transfer.
- **Destination Interpolation**: Constructs the full remote destination path
using `interpolate_remote`, combining the credentials with the `dest_path` from
`input_file`.
- **Asynchronous Transfer**: Executes `rsync` in a non-blocking manner to
transfer the file to the remote destination, preserving the file's relative
path on the remote system.
- **Hash Generation (TODO)**: Generates an MD5 hash for the source file
post-transfer. Placeholder code for generating and comparing hashes for the
source and destination files is provided but not fully implemented.

"""
function transfer_to_remote(input_file::TransferFile, credentials::Credentials)
    @info """
    Now using thread $(Threads.threadid()) to transfer
    $(basename(input_file.source_path)) to destination.
    """

    @assert isfile(input_file.source_path) """
    Input file path does not point to a file path that exists:\n$(input_file.source_path)
    """

    # pull out the source path and interpolate the destination
    source_path = input_file.source_path
    destination = interpolate_remote(
        credentials.username,
        credentials.address,
        input_file.dest_path,
    )

    # run the transfer asynchronously with rsync
    run(`rsync -aqzR $source_path $destination`)

    # TODO:
    # hash the original and destination files. The origin hash will take
    # place while the transfer finishes
    input_file.origin_hash = open(MD5.md5, source_path) |> bytes2hex
    # input_file.destination_hash = open(MD5.md5, destination) |> bytes2hex

    # TODO:
    # log a non-fatal error if the transfer fails according to hashes
    # if input_file.origin_hash != input_file.destination_hash
    #     @error "$destination failed to transfer successfully and may be corrupted or absent on the remote destination."
    # end

end
precompile(transfer_to_remote, (TransferFile, Credentials))


"""
    oversee_transfers(queue::TransferQueue, creds::Credentials, to_or::Bool)

Manages and executes the transfer of a queue of files between a local system
and a remote host in parallel, using available CPU cores. This function adapts
its behavior based on the direction of the transfer, either to the remote host
or from it, as specified by the `to_or` flag.

### Parameters
- `queue::TransferQueue`: An instance of `TransferQueue` containing the files
(`TransferFile` instances) to be transferred. Each file includes source and
destination paths, along with placeholders for hash values.
- `creds::Credentials`: An instance of `Credentials` providing the necessary
authentication details for accessing the remote host, including the remote
    address, username, and base directory.
- `to_or::Bool`: A boolean flag determining the direction of the transfer.
`true` indicates transfer to the remote host (`transfer_to_remote`), and
`false` indicates transfer from the remote host (`transfer_from_remote`).

### Behavior
- **Thread Warning**: If Julia is running on a single thread, a warning is
logged, advising that performance may be impacted due to sequential file
transfer.
- **Parallel Transfers**: The function initiates file transfers in parallel,
leveraging Julia's `@threads` macro to distribute the transfer tasks across
available CPU cores.
- **Direction Handling**: Based on the `to_or` flag, the function decides
whether to invoke `transfer_to_remote` or `transfer_from_remote` for each file
in the `queue`.

"""
function oversee_transfers(
    queue::TransferQueue,
    creds::Credentials,
    to_or::Bool,
)
    # print a warning if running on a single thread
    Threads.nthreads() < 2 && @warn """
    TractorBeam appears to be running on a single thread, whichs means that
    only one file can be transferred at a time. Performance may be slow.
    """

    # run as many transfers as there are CPU cores available to the Julia runtime
    @threads for file in queue.files

        # TODO
        # this will probably cause a data race but oh well
        # queue.remaining = queue.member_count - i
        # queue.progress = queue.remaining / queue.member_count

        if to_or
            transfer_to_remote(file, creds)
            continue
        end

        transfer_from_remote(file)
    end
end
precompile(oversee_transfers, (TransferQueue, Bool))


"""
    run_remote_command(command::String, creds::Credentials)

Executes a specified command on a remote host using SSH, within the directory
specified in the provided credentials. This function constructs an SSH command
string using the authentication details and the target directory from `creds`,
then executes the given `command` remotely.

### Parameters
- `command::String`: The command to be executed on the remote host. This
command is executed in the remote directory specified by `creds.remote_dir`.
- `creds::Credentials`: An instance of `Credentials` providing the necessary
authentication details for accessing the remote host, including the remote
address, username, and the base directory where the command should be executed.

### Returns
- The result of the `run` function, which executes the constructed SSH command.
This typically includes the standard output and error of the remote command
execution, depending on how `run` is configured and used within the Julia
environment.

### Behavior
- **SSH Command Construction**: Forms an SSH command that logs into the remote
host using the details from `creds` and then changes to the directory specified
by `creds.remote_dir` before executing the provided `command`.
- **Command Execution**: The remote command execution is performed in a single
SSH session, ensuring that the command runs in the specified remote directory.
The command is combined with a `cd` operation to navigate to the correct
directory, using `&&` to chain the directory change with the actual command
execution.

### Notes
- Ensure that SSH key-based authentication is configured for the target host
to avoid interruptions or the need for password input during command execution.
- The remote directory path (creds.remote_dir) should be valid and accessible
to the user specified by creds.username to prevent errors during the cd
operation.
- This function is a simple wrapper around SSH for executing remote commands
and does not inherently provide features like output parsing or error handling.
Additional logic may be required to handle these aspects based on the command's
output or exit status.

### Limitations
The execution context (e.g., environment variables) of the remote command will
be that of the default shell initialized by SSH, which may differ from the
context of an interactive login shell.
"""
function run_remote_command(command::String, creds::Credentials)
    # put together details for ssh
    ssh_details = "$(creds.username)@$(creds.address)"

    # run the command on the remote host
    return run(`ssh $ssh_details cd $(creds.remote_dir) \&\& $command`)
end
precompile(run_remote_command, (String, Credentials))


"""
    make_result_file_queue(credentials::Credentials, remote_results_dir::String, local_results_dir::String)::TransferQueue

Prepares a `TransferQueue` for transferring files from a specified directory on
a remote host to a corresponding directory on the local machine. This function
dynamically generates the list of files to be transferred based on the current
contents of the remote results directory, excluding system-specific files
(e.g., `.DS_Store`).

### Parameters
- `credentials::Credentials`: Authentication details for accessing the remote
host, including username and address.
- `remote_results_dir::String`: The absolute path to the directory on the
remote host containing the results files to be transferred.
- `local_results_dir::String`: The target directory on the local machine where
the results files will be placed.

### Returns
- `TransferQueue`: An instance containing a queue of `TransferFile` structs,
each representing a file to be transferred from the remote to the local results
directory. Initial hash values for integrity checks are left blank.

### Behavior
- **Remote File Listing**: Executes an SSH command to list all files
(`find . -type f`) within the `remote_results_dir`, filtering out empty lines
and system-specific files.
- **Path Preparation**: Constructs full remote paths (for SSH transfers) and
corresponding local destination paths for each file, adjusting paths to ensure
they are relative to the specified result directories.
- **Queue Assembly**: Creates a `TransferQueue` with `TransferFile` instances
for each file identified, ready for transfer. The queue tracks the total number
of files and initializes transfer progress to `0.0`.

### Example Usage
```julia
creds = Credentials("example.com", "user123", "/path/to/remote")
remote_dir = "/remote/results"
local_dir = "local/results"
queue = make_result_file_queue(creds, remote_dir, local_dir)
# `queue` is now ready for processing file transfers from `remote_dir` to `local_dir`.
```

### Notes
- The function leverages functional programming paradigms for clear, concise,
and composable code structure, making extensive use of piping (@pipe) for data
transformation.
- System files like .DS_Store are explicitly excluded from the transfer list to
prevent unnecessary file transfers.
Full paths for both source (remote) and destination (local) files are
meticulously constructed to ensure accurate transfers.
- TODO: Implement functionality for generating and verifying file hashes to
ensure data integrity post-transfer.

### Limitations
- Assumes ssh and find commands are available and correctly configured on both
the local machine and the remote host.
- Does not yet implement hash generation or verification for transferred files,
which is crucial for validating the integrity of transferred data.`
"""
function make_result_file_queue(
    credentials::Credentials,
    remote_results_dir::String,
    local_results_dir::String,
)::TransferQueue

    username = credentials.username
    address = credentials.address
    host = "$username@$address"

    # lazily generate the the list of relative paths to be transferred back
    bring_em_home = @pipe read(
              `ssh $host cd $remote_results_dir \&\& find . -type f`,
              String,
          ) |>
          split(_, '\n') |>
          filter(x -> x != "") |>
          filter(x -> x |> !contains(".DS_Store")) |>
          replace.(_, "./" => "")

    # fill in the remaining parts for each relative path so we have
    # complete remote host address
    remote_paths = @pipe bring_em_home |>
          map(x -> "$host:$remote_results_dir/$x", _) |>
          collect

    # fill in the local output directory information so we know where
    # the files will eventually end up
    dest_paths = @pipe bring_em_home |>
          map(x -> "$local_results_dir/$x", _) |>
          collect |>
          dirname.(_) |>
          map(x -> "$x/", _)

    # TODO generate hashes for all the files to be transferred

    # create a vector of TransferFile instances that will themselves be
    # contained in an instance of the TransferQueue struct
    transfer_files = [
        TransferFile(source_path, dest_path, "", "") for
        (source_path, dest_path) in zip(remote_paths, dest_paths)
    ]

    # return the TransferQueue
    return TransferQueue(
        transfer_files,
        length(transfer_files),
        length(transfer_files),
        0.0,
    )
end
precompile(make_result_file_queue, (String, String))


"""
    transfer_from_remote(result_file::TransferFile)

Initiates the transfer of a single file from a remote host to a local
destination using `rsync`. This function handles the creation of the necessary
local directories and performs the file transfer operation. It logs the
transfer process, including the thread on which the transfer is executed, for
better traceability and debugging.

### Parameters
- `result_file::TransferFile`: An instance of `TransferFile` representing the
file to be transferred back to the local machine. This struct includes the
source path (remote), destination path (local), and placeholders for hash
values to verify transfer integrity.

### Behavior
- **Directory Preparation**: Ensures the local destination directory exists by
creating it if necessary, using `mkdir -p`. This preemptive step prevents
    `rsync` from failing due to missing directories.
- **File Transfer**: Executes an `rsync` command to transfer the file from the
remote source path to the local destination path, using flags for archive mode,
quiet operation, and compression.
- **Hashing (TODO)**: Placeholder logic is provided for generating MD5 hash
values of the file at both the source and destination, intended for future
implementation to verify the integrity of the transferred file.
- **Error Handling (TODO)**: Outlines a structure for logging errors if hash
verification indicates the file transfer was unsuccessful, potentially due to
corruption or loss.
"""
function transfer_from_remote(result_file::TransferFile)
    @info """
    Now transferring $(basename(result_file.source_path)) back to local
    destination on thread $(Threads.threadid()).
    """

    # run the transfer with rsync
    run(`mkdir -p $(result_file.dest_path)`)
    run(`rsync -aqz $(result_file.source_path) $(result_file.dest_path)`)

    # TODO:
    # hash the original and destination files. The origin hash will take
    # place while the transfer finishes
    # result_file.origin_hash = open(MD5.md5, source_path) |> bytes2hex
    # result_file.destination_hash = open(MD5.md5, destination) |> bytes2hex

    # TODO:
    # log a non-fatal error if the transfer fails according to hashes
    # if result_file.origin_hash != result_file.destination_hash
    #     @error "$destination failed to transfer successfully and may be corrupted or absent."
    # end

    return
end
precompile(transfer_from_remote, (TransferFile,))


end # module TractorBeam
