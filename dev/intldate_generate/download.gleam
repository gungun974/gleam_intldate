import gleam/bit_array
import gleam/crypto
import gleam/http/request
import gleam/httpc
import gleam/list
import gleam/result
import gleam/string
import intldate_generate/log
import simplifile
import star

type Source {
  Source(id: String, version: String, url: String, root: String, sha256: String)
}

pub fn download(
  id id: String,
  version version: String,
  url url: String,
  root root: String,
  sha256 sha256: String,
) -> String {
  do_download(Source(id:, version:, url:, root:, sha256:))
}

@target(erlang)
fn do_download(source: Source) -> String {
  case prepare(source) {
    Ok(path) -> path
    Error(message) -> panic as message
  }
}

@target(javascript)
fn do_download(_source: Source) -> String {
  panic as "ICU source generation is only supported on Erlang"
}

@target(erlang)
fn prepare(source: Source) -> Result(String, String) {
  use archive <- result.try(prepare_archive(source))
  case source_is_prepared(source) {
    True -> {
      log.skipped("ICU source extraction", "sources already prepared")
      Ok(source_root(source))
    }
    False ->
      extract_source(source, archive)
      |> result.replace(source_root(source))
  }
}

@target(erlang)
fn prepare_archive(source: Source) -> Result(String, String) {
  let downloads_dir = downloads_dir()
  let archive_path = archive_path(source)
  use _ <- result.try(
    simplifile.create_directory_all(downloads_dir)
    |> filesystem_result("create the source download cache"),
  )
  case simplifile.read_bits(archive_path) {
    Ok(contents) ->
      case checksum_is_valid(contents, source.sha256) {
        True -> {
          log.skipped("ICU archive download", "archive already cached")
          Ok(archive_path)
        }
        False -> {
          use _ <- result.try(
            simplifile.delete_all([archive_path])
            |> filesystem_result("delete the invalid source archive"),
          )
          download_archive(source)
        }
      }
    Error(simplifile.Enoent) -> download_archive(source)
    Error(error) ->
      Error(
        "Could not read the source archive cache: "
        <> simplifile.describe_error(error),
      )
  }
}

@target(erlang)
fn download_archive(source: Source) -> Result(String, String) {
  log.step("ICU archive download", fn() { do_download_archive(source) })
}

@target(erlang)
fn do_download_archive(source: Source) -> Result(String, String) {
  let archive_path = archive_path(source)
  let archive_temporary_path = archive_path <> ".part"
  use source_request <- result.try(
    request.to(source.url)
    |> result.map_error(fn(_) { "Invalid source URL" }),
  )
  let source_request = request.set_body(source_request, <<>>)
  let configuration =
    httpc.configure()
    |> httpc.follow_redirects(True)
    |> httpc.timeout(300_000)
  use response <- result.try(
    httpc.dispatch_bits(configuration, source_request)
    |> result.map_error(fn(error) {
      "Could not download source: " <> string.inspect(error)
    }),
  )
  use contents <- result.try(case response.status {
    status if status >= 200 && status < 300 -> Ok(response.body)
    status -> Error("Source download returned HTTP " <> string.inspect(status))
  })
  case checksum_is_valid(contents, source.sha256) {
    False ->
      Error(
        "Source checksum mismatch: expected "
        <> source.sha256
        <> ", got "
        <> checksum(contents),
      )
    True -> {
      use _ <- result.try(
        simplifile.delete_all([archive_temporary_path])
        |> filesystem_result("delete the temporary source archive"),
      )
      use _ <- result.try(
        simplifile.write_bits(archive_temporary_path, contents)
        |> filesystem_result("write the temporary source archive"),
      )
      use _ <- result.try(
        simplifile.rename(archive_temporary_path, archive_path)
        |> filesystem_result("move the source archive into the cache"),
      )
      Ok(archive_path)
    }
  }
}

@target(erlang)
fn extract_source(source: Source, archive_path: String) -> Result(Nil, String) {
  log.step("ICU source extraction", fn() {
    do_extract_source(source, archive_path)
  })
}

@target(erlang)
fn do_extract_source(
  source: Source,
  archive_path: String,
) -> Result(Nil, String) {
  let sources_dir = sources_dir(source)
  let source_root = source_root(source)
  let source_marker = source_marker(source)
  use _ <- result.try(
    simplifile.delete_all([sources_dir])
    |> filesystem_result("clear the extracted source cache"),
  )
  use _ <- result.try(
    simplifile.create_directory_all(sources_dir)
    |> filesystem_result("create the extracted source cache"),
  )
  use headers <- result.try(
    star.list(
      from: star.FromFile(archive_path),
      compression: star.Gzip,
      filter: star.AllEntries,
    )
    |> result.map_error(fn(error) {
      "Could not list source archive: " <> string.inspect(error)
    }),
  )
  let extractable_entries =
    list.filter_map(headers, fn(header) {
      case header.entry_type {
        star.Symlink | star.HardLink -> Error(Nil)
        _ -> Ok(header.name)
      }
    })
  use _ <- result.try(
    star.extract(
      from: star.FromFile(archive_path),
      to: sources_dir,
      compression: star.Gzip,
      filter: star.Only(extractable_entries),
      on_conflict: star.Overwrite,
    )
    |> result.map_error(fn(error) {
      "Could not extract source archive: " <> string.inspect(error)
    }),
  )
  use is_directory <- result.try(
    simplifile.is_directory(source_root)
    |> filesystem_result("check the extracted ICU source"),
  )
  case is_directory {
    False -> Error("The source archive did not contain " <> source_root)
    True ->
      simplifile.write(source_marker, source.sha256 <> "\n")
      |> filesystem_result("write the source marker")
  }
}

@target(erlang)
fn source_is_prepared(source: Source) -> Bool {
  case
    simplifile.read(source_marker(source)),
    simplifile.is_directory(source_root(source))
  {
    Ok(marker), Ok(True) -> string.trim(marker) == source.sha256
    _, _ -> False
  }
}

@target(erlang)
fn checksum_is_valid(contents: BitArray, expected: String) -> Bool {
  checksum(contents) == expected
}

@target(erlang)
fn downloads_dir() -> String {
  "./.cache/downloads"
}

@target(erlang)
fn archive_path(source: Source) -> String {
  downloads_dir() <> "/" <> source.id <> "-" <> source.version <> ".tar.gz"
}

@target(erlang)
fn sources_dir(source: Source) -> String {
  "./.cache/sources/" <> source.id
}

@target(erlang)
fn source_root(source: Source) -> String {
  sources_dir(source) <> "/" <> source.root
}

@target(erlang)
fn source_marker(source: Source) -> String {
  sources_dir(source) <> "/.source-sha256"
}

@target(erlang)
fn checksum(contents: BitArray) -> String {
  crypto.hash(crypto.Sha256, contents)
  |> bit_array.base16_encode
  |> string.lowercase
}

@target(erlang)
fn filesystem_result(
  operation: Result(value, simplifile.FileError),
  description: String,
) -> Result(value, String) {
  operation
  |> result.map_error(fn(error) {
    "Could not " <> description <> ": " <> simplifile.describe_error(error)
  })
}
