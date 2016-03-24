#define TRACE
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;

/// <summary>
/// Summary description for Class1
/// </summary>
public class SansaDatabase
{
	private string hdrPath = null;
	private string datPath = null;
	private const int expectedpredatfieldoffsetpadding = 1088;
	private const int H10DB_MAX_DAT_ENTRIES = 5000;

	public int unknown1;
	public int unknown2;
	public string pathname_dat;
	public int unknown3;
	public string pathname_hdr;
	public int unknown4;
	public int num_dat_records;
	public int num_dat_inactive_records;
	public int num_dat_fields;
	public FieldDescriptor[] fd;

	public int[] max_dat_field_offsets;
	public int dat_size;
	public int unknown5;
	public Int16[,] dat_field_offset;
	public int[] dat_record_offset;

	public Hashtable[] data;

	public class FieldDescriptor
	{
		public int id;
		public int field_type;
		public int max_length;
		public int unknown5;
		public int unknown6;
		public int has_index;
		public int unknown7;
		public int unknown8;
		public string idx_pathname;

		internal FieldDescriptor(StreamConverter str)
		{
			id = str.GetInt32();
			field_type = str.GetInt32();
			max_length = str.GetInt32();
			unknown5 = str.GetInt32();
			unknown6 = str.GetInt32();
			has_index = str.GetInt32();
			unknown7 = str.GetInt32();
			unknown8 = str.GetInt32();
			idx_pathname = str.GetString(256);
		}

	}

	public SansaDatabase()
	{
	}

	public void Load(string hdrPath, string datPath)
	{
		this.hdrPath = hdrPath;
		this.datPath = datPath;
		
		using (FileStream fs = File.OpenRead(hdrPath)) 
        {
			using (StreamConverter str = new StreamConverter(fs))
			{
				unknown1 = str.GetInt32();
				unknown2 = str.GetInt32();
				pathname_dat = str.GetString(256);
				unknown3 = str.GetInt32();
				pathname_hdr = str.GetString(256);
				unknown4 = str.GetInt32();
				num_dat_records = str.GetInt32();
				num_dat_inactive_records = str.GetInt32();
				num_dat_fields = str.GetInt32();
				fd = new FieldDescriptor[num_dat_fields+2];

				for (int i = 0; i < num_dat_fields+2; ++i)
				{
					fd[i] = new FieldDescriptor(str);
				}

				max_dat_field_offsets = new int[num_dat_fields+2];

				for (int i = 0; i < num_dat_fields+2; ++i)
				{
					max_dat_field_offsets[i] = str.GetInt32();
				}

				dat_size = str.GetInt32();
				unknown5 = str.GetInt32();
				dat_field_offset = new Int16[H10DB_MAX_DAT_ENTRIES,num_dat_fields+2];

				for (int i = 0; i < H10DB_MAX_DAT_ENTRIES; ++i)
					for (int j = 0 ; j < num_dat_fields+2; ++j)
					{
						dat_field_offset[i,j] = str.GetInt16();
					}

				dat_record_offset = new int[H10DB_MAX_DAT_ENTRIES+1];

				for (int i = 0; i < H10DB_MAX_DAT_ENTRIES; ++i)
					dat_record_offset[i] = str.GetInt32();
			}
        }

		List<string> names = new List<string>();
		names.Add("dev");
		names.Add("FilePath");
		names.Add("FileName");
		names.Add("Format");
		names.Add("mtpf");
		names.Add("TrackTitle");
		names.Add("ArtistName");
		names.Add("AlbumTitle");
		names.Add("Genre");
		names.Add("AlbumTrack");
		names.Add("TrackComposerQ");
		names.Add("du1");
		names.Add("Yearx12MonthQ");
		names.Add("RhapsodyTrackID");
		names.Add("UserRating");
		names.Add("FileLength");
		names.Add("CopyrightDataQ");
		names.Add("RhapsodyArtistID");
		names.Add("RhapsodyAlbumID");
		names.Add("RhapsodyGenreID");
		names.Add("57350");
		names.Add("PlayCount");
		names.Add("du8");
		names.Add("57352");
		names.Add("97");
		names.Add("ratg");
		names.Add("YearQ");
		names.Add("61449");
		names.Add("mgen");
		names.Add("buyf");
		names.Add("142");

		data = new Hashtable[num_dat_records];
                      
		using (FileStream fs = File.OpenRead(datPath))
		{
			using (StreamConverter str = new StreamConverter(fs))
			{
				for (int i = 0; i < num_dat_records; ++i)
				{
					if ((0 == dat_record_offset[i]) && (0 != i))
						continue; // nothing to load, move on to next
					data[i] = new Hashtable(num_dat_fields);
					for (int j = 0; j < num_dat_fields; ++j)
					{
						str.Position = dat_record_offset[i] + dat_field_offset[i,j];
						switch (fd[j].field_type)
						{
							case 1:
								data[i].Add(names[j], str.GetString());
								break;
							case 2:
								data[i].Add(names[j], str.GetInt32());
								break;
							default:
								throw new ApplicationException("Unrecognized field type " + fd[j].field_type.ToString() + " in " + i.ToString() + "," + names[j]);

						}

					}
					data[i].Add("__index", i);
				}
			}
		}
	}


}

internal class StreamConverter : System.IO.Stream
{
	private System.IO.Stream str = null;
	private static byte[] buffer = new byte[4];
	private static System.Text.StringBuilder sb = new System.Text.StringBuilder(256);

	public StreamConverter(System.IO.Stream str)
	{
		if (!str.CanSeek)
			throw new ApplicationException("Unable to seek in stream being decorated");

		this.str = str;
	}

	public Int16 GetInt16()
	{
		if (2 != str.Read(buffer, 0, 2))
			throw new System.IO.EndOfStreamException();
		return BitConverter.ToInt16(buffer, 0);
	}

	public char GetWChar()
	{
		if (2 != str.Read(buffer, 0, 2))
			throw new System.IO.EndOfStreamException();
		return BitConverter.ToChar(buffer, 0);
	}

	public int GetInt32()
	{
		if (4 != str.Read(buffer, 0, 4))
			throw new System.IO.EndOfStreamException();
		return BitConverter.ToInt32(buffer, 0);
	}

	public string GetString()
	{
		sb.Length = 0;
		while (true)
		{
			char ch = GetWChar();
			if ('\0' == ch)
				return sb.ToString();
			sb.Append(ch);
		}
	}

	public string GetString(int padToSize)
	{
		sb.Length = 0;
		int i;
		//System.Diagnostics.Trace.WriteLine("GetString: Position = " + str.Position.ToString());
		for (i = 0; i < padToSize; ++i)
		{
			char ch = GetWChar();
			if ('\0' == ch)
				break;
			sb.Append(ch);
		}
		str.Position += ((padToSize - i - 1) * sizeof(char));
		//System.Diagnostics.Trace.WriteLine("GetString: Position = " + str.Position.ToString());
		return sb.ToString();
	}

	override public int Read(/*[InAttribute] [OutAttribute]*/ byte[] buffer, int offset, int count)
	{
		return str.Read(buffer, offset, count);
	}

	override public void Write (byte[] buffer, int offset, int count)
	{
		str.Write(buffer, offset, count);
	}

	override public int ReadByte()
	{
		if (1 != str.Read(buffer, 0, 1))
			return -1;
		return buffer[0];
	}

	override public void WriteByte(byte value)
	{
		buffer[0] = value;
		str.Write(buffer, 0, 1);
	}

	override public bool CanRead { get { return str.CanRead; } }
	override public bool CanWrite { get { return str.CanWrite; } }
	override public bool CanSeek { get { return str.CanSeek; } }

	override public void Flush()
	{
		str.Flush();
	}

	override public long Length { get { return str.Length; } }

	override public long Position {
		get { return str.Position;}
		set { str.Position = value;}
	}

	override public long Seek(long offset, SeekOrigin origin)
	{
		return str.Seek(offset, origin);
	}

	override public void SetLength(long value)
	{
		str.SetLength(value);
	}

	protected override void Dispose(bool disposing)
	{
		if (null != str)
		{
			str.Dispose();
			str = null;
			base.Dispose(disposing);
		}
	}

	new public void Dispose()
	{
		Dispose(true);
		// Take yourself off the Finalization queue 
		// to prevent finalization code for this object
		// from executing a second time.
		GC.SuppressFinalize(this);
	}






}