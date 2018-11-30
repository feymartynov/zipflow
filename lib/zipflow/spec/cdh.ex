defmodule Zipflow.Spec.CDH do
  @moduledoc """
  The central directory header, the last bits of a zip archive. Each
  entry in a zipfile contains a local header which is accompanied by a
  corresponding central header within the central directory header.
  """

  @doc """
  encode the central directory headers and the end of central
  directory header. each entry you add to a zip archive using
  `Zipflow.Spec.LFH` and `Zipflow.Spec.Entry` [one of its
  implementation] generates a value that must be kept and used here
  in the `contents` arguments. you must provide them in order, as a
  list of tuple `{LFH, Entry}`.

  # example #

  ```
  iex> entry = Zipflow.DataEntry.encode(&IO.binwrite/1, "foobar", "foobar")
  ...> Zipflow.Spec.CDH.encode(&IO.binwrite/1, [entry])
  ```
  """
  @spec encode((binary -> any), [{Zipflow.Spec.LFH.t, Zipflow.Spec.Entry.t}]) :: any
  def encode(printer, contents) do
    {entries, offset, size} =
      Enum.reduce(contents, {0, 0, 0}, fn {hframe, dframe}, {entries, offset, size} ->
        {file_header_offset, file_header_size} = header(printer, offset, hframe, dframe)
        {entries + 1, offset + file_header_offset, size + file_header_size}
      end)

    frame = <<
      # ZIP64 end of central directory record
      0x06064b50              :: size(32)-little, # signature
      44                      :: size(64)-little, # size of ZIP64 end of central directory record
      20                      :: size(16)-little, # version made by
      0x0a                    :: size(16)-little, # version needed to extract
      0                       :: size(32)-little, # number of this disk
      0                       :: size(32)-little, # number of disks w/ the start of the CD
      entries                 :: size(64)-little, # total number of entries in the CD on this disk
      entries                 :: size(64)-little, # total number of entries in the CD
      size                    :: size(64)-little, # size of the CD
      offset                  :: size(64)-little, # offset of the CD
      # ZIP64 end of central directory locator
      0x07064b50              :: size(32)-little, # signature
      0                       :: size(32)-little, # number of the disk w/ the start of the ZIP64 ECD
      (offset + size)         :: size(64)-little, # relative offset of the ZIP64 ECD
      1                       :: size(32)-little, # total number of disks
      # end of central directory record
      0x06054b50              :: size(32)-little, # signature
      0                       :: size(16)-little, # number of this disk
      0                       :: size(16)-little, # number of the disk w/ ECD
      min(entries, 0xffff)    :: size(16)-little, # total number of entries in this disk
      min(entries, 0xffff)    :: size(16)-little, # total number of entries in the ECD
      min(size, 0xffffffff)   :: size(32)-little, # size central directory
      min(offset, 0xffffffff) :: size(32)-little, # offset central directory
      0                       :: size(16)-little  # zip file comment length
    >>

    printer.(frame)
  end

  defp header(printer, offset, hframe, dframe) do
    frame = <<
      0x02014b50                      :: size(32)-little, # central file header signature
      20                              :: size(16)-little, # version made by
      0x0a                            :: size(16)-little, # version to extract
      8                               :: size(16)-little, # general purpose flag
      0                               :: size(16)-little, # compression method
      0                               :: size(16)-little, # last mod file time
      0                               :: size(16)-little, # last mod file date
      dframe[:crc]                    :: size(32)-little, # crc-32
      min(dframe[:csize], 0xffffffff) :: size(32)-little, # compressed size
      min(dframe[:usize], 0xffffffff) :: size(32)-little, # uncompressed size
      hframe[:n_size]                 :: size(16)-little, # file name length
      32                              :: size(16)-little, # extra field length
      0                               :: size(16)-little, # file comment length
      0                               :: size(16)-little, # disk number start
      0                               :: size(16)-little, # internal file attribute
      0                               :: size(32)-little, # external file attribute
      min(offset, 0xffffffff)         :: size(32)-little, # relative offset header
    >>

    extra_field = <<
      0x0001                          :: size(16)-little, # ZIP64 extended information
      28                              :: size(16)-little, # data size
      dframe[:usize]                  :: size(64)-little, # uncompressed file size
      dframe[:csize]                  :: size(64)-little, # compressed file size
      offset                          :: size(64)-little, # relative offset of local header
      0                               :: size(32)-little  # disk start number
    >>

    printer.(frame)
    printer.(hframe[:name])
    printer.(extra_field)
    {hframe[:size] + dframe[:size], byte_size(frame) + hframe[:n_size] + byte_size(extra_field)}
  end
end
