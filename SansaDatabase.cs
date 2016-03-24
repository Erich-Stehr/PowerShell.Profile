#define TRACE
using System;
using System.Diagnostics;
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
	static private List<string> names;


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

		internal void Dump(StreamConverter str)
		{
			str.PutInt32(id);
			str.PutInt32(field_type);
			str.PutInt32(max_length);
			str.PutInt32(unknown5);
			str.PutInt32(unknown6);
			str.PutInt32(has_index);
			str.PutInt32(unknown7);
			str.PutInt32(unknown8);
			str.PutString(idx_pathname, 256);
		}
	}

	static SansaDatabase()
	{
		names = new List<string>();		//	ID	 bytes	idx
		names.Add("dev");				// 61441 4		@DEV	0
		names.Add("FilePath");			// 61442 256	FPTH	1
		names.Add("FileName");			// 61443 256	FNAM	2
		names.Add("Format");			// 61450 4		FRMT	3
		names.Add("mtpf");				// 61451 4		MTPF	4
		names.Add("TrackTitle");		// 46	 256	TIT2	5
		names.Add("ArtistName");		// 60	 256	TPE1	6
		names.Add("AlbumTitle");		// 28	 256	TALB	7
		names.Add("Genre");				// 31	 256	TCON	8
		names.Add("AlbumTrack");		// 67	 4		TRCK	9
		names.Add("TrackComposerQ");	// 30	 40		TCOM	10
		names.Add("du1");				// 57344 80		@DU1	11
		names.Add("Yearx12MonthQ");		// 57345 4		@DU2	12
		names.Add("RhapsodyTrackID");	// 57346 4		@DU3	13
		names.Add("UserRating");		// 18	 4		POPM	14
		names.Add("FileLength");		// 61447 4				15
		names.Add("CopyrightDataQ");	// 32	 30				16
		names.Add("RhapsodyArtistID");	// 57347 4				17
		names.Add("RhapsodyAlbumID");	// 57348 4				18
		names.Add("RhapsodyGenreID");	// 57349 4				19
		names.Add("57350");				// 57350 4				20
		names.Add("PlayCount");			// 17	 4		PCNT	21
		names.Add("du8");				// 57351 4		@DU8	22
		names.Add("57352");				// 57352 4				23
		names.Add("97");				// 97	 4				24
		names.Add("ratg");				// 93	 4		RATG	25
		names.Add("YearQ");				// 78	 4				26
		names.Add("61449");				// 61449 4				27
		names.Add("mgen");				// 140	 4		MGEN	28
		names.Add("buyf");				// 141	 4		BUYF	29
		names.Add("142");				// 142	 4				30

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
				for (int i = 0; i <= H10DB_MAX_DAT_ENTRIES; ++i)
					dat_record_offset[i] = str.GetInt32();
			}
        }

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
								data[i].Add(names[j], str.GetString((dat_field_offset[i, j+1] - dat_field_offset[i, j])/2, StreamConverter.StringGrab.EntireBuffer));
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

	public void Save()
	{
		this.Save(this.hdrPath, this.datPath);
	}

	public void Save(string hdrPath, string datPath)
	{
		int offTrackThis = 0; //The current track being worked on
		int offTrackNext = 0; //The next track, for skipping over _Sansa_Delete'd tracks

		//System.Diagnostics.Trace.Listeners.Add(new System.Diagnostics.DefaultTraceListener());
		Trace.AutoFlush = true;
 
		MemoryStream ms = new MemoryStream();  

		using (StreamConverter str = new StreamConverter(ms))
		{
			//fill in 	dat_field_offset, dat_record_offset from data;
			// use __Sansa_Delete to unroot the record
			for (offTrackThis = offTrackNext = 0; offTrackNext < num_dat_records; ++offTrackNext)
			{
				System.Diagnostics.Trace.WriteLine(String.Format("Data Track {0:D}: offset {1:D} 0x{1:x}",
							offTrackThis, str.Position));
				Hashtable ht = this.data[offTrackNext];
				if (ht.ContainsKey("__Sansa_Delete"))
					continue;

				int record_offset;
				this.dat_record_offset[offTrackThis] = record_offset = (int)str.Position;
				str.PutInt32(0);
				str.PutInt32(0);
				for (int i = 0; i < names.Count; ++i)
				{
					// Bug-for-bug error on preloaded .mp3's; field 22 offset == 0 instead of allocating .dat space; works because mine isn't in the default folder "MUSIC\\"
					if ((22 == i) && (((string)ht["FilePath"]).StartsWith("MUSIC\\")))
					{
						dat_field_offset[offTrackThis, i] = 0;
						continue;
					}

					dat_field_offset[offTrackThis,i] = (Int16)((int)str.Position - record_offset);
					switch (this.fd[i].field_type)
					{
						case 1: //String
							string s = ht[names[i]].ToString();
							s = s.Substring(0, Math.Min(s.Length, this.fd[i].max_length));
							str.PutString(s);
							break;
						case 2: //Int32
							int val;
							object obj = ht[names[i]];
							if (obj.GetType() == typeof(int))
								val = (int)obj;
							else
								Int32.TryParse(obj.ToString(), out val); //we want 0 if not parsable
							str.PutInt32(val);
							break;
						default:
							throw new ApplicationException(String.Format("Unrecognized field type {2} in {0},{1}", offTrackThis, i, this.fd[i].field_type));
					}
				}
				offTrackThis++; //completed this one, place next in next
			}

			//now that we know how many exist (offTrackThis), reset the num_dat_records
			num_dat_records = offTrackThis++;
			for (; offTrackThis < offTrackNext; ++offTrackThis)
			{
				this.dat_record_offset[offTrackThis] = 0;
				for (int i = 0; i < names.Count; ++i)
					this.dat_field_offset[offTrackThis, i] = 0;
			}
		}
		dat_size = (int)ms.Length;


		//pour header based on data
		using (FileStream fs = File.OpenWrite(hdrPath)) 
		{
			using (StreamConverter str = new StreamConverter(fs)) 				{
				str.PutInt32(unknown1); 
				str.PutInt32(unknown2);
				str.PutString(pathname_dat, 256);
				str.PutInt32(unknown3);
				str.PutString(pathname_hdr, 256);
				str.PutInt32(unknown4);
				str.PutInt32(num_dat_records);
				str.PutInt32(num_dat_inactive_records);
				str.PutInt32(num_dat_fields);

				for (int i = 0; i < num_dat_fields+2; ++i)
				{
					System.Diagnostics.Trace.WriteLine(String.Format("Header fd {0:d}: offset {1:d} 0x{1:x}",
								i, str.Position));
					fd[i].Dump(str);
				}

				System.Diagnostics.Trace.WriteLine(String.Format("Header max_dat_field_offsets: offset {1} 0x{1:x}",
				            0, str.Position));
				for (int i = 0; i < num_dat_fields+2; ++i)
				{
					str.PutInt32(max_dat_field_offsets[i]);
				}

				str.PutInt32(dat_size);
				str.PutInt32(unknown5);

				System.Diagnostics.Trace.WriteLine(String.Format("Header dat_field_offset: offset {1} 0x{1:x}",
				            0, str.Position));
				for (int i = 0; i < H10DB_MAX_DAT_ENTRIES; ++i)
					for (int j = 0 ; j < num_dat_fields+2; ++j)
					{
						str.PutInt16(dat_field_offset[i,j]);
					}

				System.Diagnostics.Trace.WriteLine(String.Format("Header dat_record_offset: offset {1} 0x{1:x}",
				            0, str.Position));
				for (int i = 0; i <= H10DB_MAX_DAT_ENTRIES; ++i)
					str.PutInt32(dat_record_offset[i]);
			}
        }

		//pour data
		using (FileStream fs = File.OpenWrite(datPath))
		{
			ms.WriteTo(fs);
			fs.SetLength(ms.Length); //Bizzare, but needed to get length right....
		}
		ms.Close();
	}


}

internal class StreamConverter : System.IO.Stream
{
	private System.IO.Stream str = null;
	private static byte[] buffer = new byte[4];
	private static System.Text.StringBuilder sb = new System.Text.StringBuilder(256);
	public enum StringGrab { EntireBuffer };


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

	public void PutInt16(Int16 value)
	{
		str.Write(BitConverter.GetBytes(value), 0, sizeof(Int16));
	}

	public char GetWChar()
	{
		if (2 != str.Read(buffer, 0, 2))
			throw new System.IO.EndOfStreamException();
		return BitConverter.ToChar(buffer, 0);
	}

	public void PutWChar(char value)
	{
		str.Write(BitConverter.GetBytes(value), 0, sizeof(char));
	}

	public int GetInt32()
	{
		if (4 != str.Read(buffer, 0, 4))
			throw new System.IO.EndOfStreamException();
		return BitConverter.ToInt32(buffer, 0);
	}

	public void PutInt32(Int32 value)
	{
		str.Write(BitConverter.GetBytes(value), 0, sizeof(Int32));
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

	public string GetString(int bufsize, StringGrab sg)
	{
		sb.Length = 0;
		sb.Capacity = bufsize;
		while (0 != bufsize--)
		{
			char ch = GetWChar();
			sb.Append(ch);
		}
		if ('\0' == sb[sb.Length - 1])
			sb.Length = sb.Length - 1; //Take out (one and only one!) trailing NUL
		return sb.ToString();
	}

	public void PutString(String value)
	{
		byte[] buf = System.Text.Encoding.Unicode.GetBytes(value); 
		str.Write(buf, 0, buf.Length);
		PutInt16(0);
		//
		//if (0 == value.Length)
		//    PutInt16(0);
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

	public void PutString(String value, int padToSize)
	{
		//padtosize in char's, not byte's!
		byte[] buf = System.Text.Encoding.Unicode.GetBytes(value);
		int len = Math.Min(buf.Length, (padToSize - 1)*sizeof(char));
		str.Write(buf, 0, len);
		for (int i = len/sizeof(char); i < padToSize; ++i )
			PutInt16(0);
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
			//str.Dispose();  //Do not dispose of stream; it may still be in use externally!
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